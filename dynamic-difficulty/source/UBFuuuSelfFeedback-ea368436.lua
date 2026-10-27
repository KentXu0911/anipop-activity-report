local UBFuuuSelfFeedback = {}

--
--
--
--



local function findUpAndLow(checklist, desiredDiff)

    local _upK = nil
    local _upV = nil
    local _upDV = nil
    
    local _lowK = nil
    local _lowV = nil
    local _lowDV = nil
    

    for k, _data in ipairs(checklist) do
        local _diff = _data.v
        if _diff > desiredDiff then
            if not _upDV then 
                _upDV = _diff - desiredDiff 
                _upK = _data.k
                _upV = _diff
            elseif _diff - desiredDiff < _upDV then
                _upDV = _diff - desiredDiff
                _upK = _data.k
                _upV = _diff
            end
        else
            if not _lowDV then 
                _lowDV = desiredDiff - _diff 
                _lowK = _data.k
                _lowV = _diff
            elseif desiredDiff - _diff < _lowDV then
                _lowDV = desiredDiff - _diff
                _lowK = _data.k
                _lowV = _diff
            end
        end
    end
    return { upK = _upK, upV = _upV, upDV = _upDV, lowK = _lowK, lowV = _lowV, lowDV = _lowDV }
end

--[[
    updv 距离upK档位的难度的差值
    lowdv 距离upK档位的难度的差值
]]
local function randomUpOrLow( updv, lowdv )
    -- updv = 28.984
    -- lowdv = 0.095

    local _r = updv / (updv + lowdv) --差值越大，随机到的概率越低
    -- 1 - ( 28.984 / ( 28.984 + 0.095 ) )
    -- 1 - ( 28.984 / ( 29.079 ) )
    -- 1 - 0.99673
    -- 0.0033
    
    if UBFuuuSelfFeedback.debugMode then printx(1,"selfFeedback ---------- randomUpOrLow  updv:" , updv, "lowdv:", lowdv) end
    local _random = math.random()
    if UBFuuuSelfFeedback.debugMode then printx(1,"selfFeedback ---------- randomUpOrLow  _r = 1 - (_updv / (_updv + lowdv) = " , _r , "  _random =" , _random ) end

    -- _random > 0.99673
    if _random > _r then
        return 1
    else
        return 2
    end
end

local function checkDiffFixByLowDiff(_diffFix, _checkmap)
    --[[
        从diffFix0档开始尝试（当前diffFix设置为0）
            如果 查表后难度 > 1.05
                diffFix降低一档，重新比对
            如果 1.03 <= 查表后难度 <= 1.05
                如果 当前diffFix >= -2
                    diffFix降低一档，重新比对
                否则
                    使用当前diffFix档位
            如果 查表后难度 < 1.03
                使用当前diffFix档位
    ]]
    local UBFuuuSelectAdjust = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuSelectAdjust")
    local _range = UBFuuuSelectAdjust:getDiffFixRange()
    if _diffFix <= _range.min then
        return _range.min
    end

    local _diff = _checkmap[_diffFix]
    if not _diff then
        return _diffFix
    elseif _diff > 1.05 then
        return checkDiffFixByLowDiff( _diffFix-1, _checkmap )
    elseif _diff > 1.03 then
        if _diffFix >= -2 then
            return checkDiffFixByLowDiff( _diffFix-1, _checkmap )
        else
            return _diffFix
        end
    else
        return _diffFix
    end
end

local function _getDiffAvgInMap(datamap, diffFix)
    if not datamap then return nil end
    local istr = tostring(diffFix)
    if datamap[istr] then
            -- body
        local _diff = datamap[istr].diff_10000
        if (not _diff) or _diff == 0 then
            _diff = datamap[istr].diff_1000
        end
        if (not _diff) or _diff == 0 then
            _diff = datamap[istr].diff_300
        end

        if _diff and  _diff ~= 0 then
            return _diff
        end
    end
    return nil
end

function UBFuuuSelfFeedback:getDiffAvgByDiffFix(levelId, diffFix, datas, levelScene)

    local usedPreAddStep = 0
    local poolkey = nil

    if datas then
        usedPreAddStep = datas.usedPreAddStep
        poolkey = datas.poolkey
    end

    local UBFuuuAdjustManager = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager"
    local _diff_ds_map = UBFuuuAdjustManager:getDiffDsMap(levelId, usedPreAddStep, {poolkey = poolkey}, levelScene)

    -- printx(1. ,"UBFuuuSelfFeedback:getDiffAvgByDiffFix  ", levelId, diffFix, datas, levelScene, "  _diff_ds_map =", tts(_diff_ds_map) )
    return _getDiffAvgInMap(_diff_ds_map, diffFix)
end



function UBFuuuSelfFeedback:findDiffFixByDesiredDiff(levelId, desiredDiff, datas, levelScene)

    local _randomSeed = nil

    local _finalDiffFix = nil
    local _feedpath = 0

    local usedPreAddStep = 0
    local isTopLevelRange = false

    if datas then
        usedPreAddStep = datas.usedPreAddStep
        _randomSeed = datas.randomSeed or os.time()
        isTopLevelRange = datas.isTopLevelRange 
    else
        _randomSeed = os.time()
    end

    math.randomseed(_randomSeed)

    local UBFuuuAdjustManager = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager"
    local _diff_ds_map = UBFuuuAdjustManager:getDiffDsMap(levelId, usedPreAddStep, {poolkey = datas.poolkey}, levelScene)

    if self.debugMode then 
        if _diff_ds_map then  
            --[[
                -10 ~ 0 ~ 5
                {
                    [-10] = {
                        diff_1000 = 6.211,
                        diff_10000 = 2.995,
                        diff_300 = 5.66,
                        diff_all = 2.974,
                        levelExp = "default",
                        levelGroup = "default",
                        levelId = 8611,
                        useAddStep = 0,
                    },
                    [-9] = {
                        diff_1000 = 3.815,
                        diff_10000 = 3.121,
                        diff_300 = 5.769,
                        diff_all = 3.121,
                        levelExp = "default",
                        levelGroup = "default",
                        levelId = 8611,
                        useAddStep = 0,
                    },
                }
            ]]
            printx( 1 , "UBFuuuSelfFeedback:findDiffFixByDesiredDiff  -------- UBFuuu_difffix_avg_map =======  ", tts( _diff_ds_map ) )  
        else
            printx( 1 , "UBFuuuSelfFeedback:findDiffFixByDesiredDiff  -------- UBFuuu_difffix_avg_map =======  nil" )  
        end
    end
    
    if self.debugMode then printx(1,"UBFuuuSelfFeedback:findDiffFixByDesiredDiff selfFeedback ---------- desiredDiff =" , desiredDiff, "_diff_ds_map = " , _diff_ds_map) end
    
    local upK = nil
    local upV = nil
    local upDV = nil
    
    local lowK = nil
    local lowV = nil
    local lowDV = nil

    local UBFuuuSelectAdjust = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuSelectAdjust")
    local _range = UBFuuuSelectAdjust:getDiffFixRange()
    local maxDiffFix = _range.max
    local minDiffFix = _range.min

    local failReason = nil
    if _diff_ds_map and desiredDiff then
        
        local _checklist = {}
        local _checkmap = {}
        for i = maxDiffFix , minDiffFix , -1 do
            local _diff = _getDiffAvgInMap(_diff_ds_map, i)
            if _diff and  _diff ~= 0 then
                table.insert(_checklist, {k=i, v=_diff})
                _checkmap[i] = _diff
            end
        end

        if #_checklist > 0 then
            local _result = findUpAndLow(_checklist, desiredDiff)

            upK = _result.upK -- 2
            upV = _result.upV
            upDV = _result.upDV -- 40.984 - 12 = 28.984

            lowK = _result.lowK -- 1
            lowV = _result.lowV
            lowDV = _result.lowDV -- 12 - 11.905 = 0.095
        end

        if self.debugMode then printx(1,"UBFuuuSelfFeedback:findDiffFixByDesiredDiff selfFeedback ---------- upK =" , upK, "upDV =", upDV, "lowK =", lowK, "lowDV =", lowDV ) end

        if desiredDiff <= 1 then
            -- 跳线，直接返回 -16
            _finalDiffFix = minDiffFix -- _finalDiffFix = -16
            _feedpath = 34
        elseif desiredDiff <= 1.03 then
            -- 跳线，返回一个不高于 1.08 难度，且diffFix尽可能接近 0 的档位
            --[[
                从diffFix0档开始尝试（当前diffFix设置为0）
                    如果 查表后难度 > 1.05
                        diffFix降低一档，重新比对
                    如果 1.03 <= 查表后难度 <= 1.05
                        如果 当前diffFix >= -2
                            diffFix降低一档，重新比对
                        否则
                            使用当前diffFix档位
                    如果 查表后难度 < 1.03
                        使用当前diffFix档位
            ]]
            _finalDiffFix = checkDiffFixByLowDiff(0, _checkmap)
            _feedpath = 35
        else

            if upDV == 0 or lowDV == 0 then
                --目标难度 和某个档位的难度 相同，直接使用这个档位
                local _r = math.random()

                if upDV == 0 then
                    if self.debugMode then printx(1,"selfFeedback ---------- random 000.1 upDV:" , upDV, "diffFix:", upK) end
                    if _r < 0.98 then
                        _finalDiffFix = upK 
                        _feedpath = 1
                    elseif _r < 0.99 then
                        _finalDiffFix = upK + 1
                        _feedpath = 2
                    else
                        _finalDiffFix = upK - 1
                        _feedpath = 3
                    end
                else
                    if self.debugMode then printx(1,"selfFeedback ---------- random 000.2 lowDV:" , lowDV, "diffFix:", lowK) end
                    _finalDiffFix = lowK 
                    _feedpath = 4
                end
                
            elseif upK and lowK then
                if math.abs(upK - lowK) == 1 then
                    --最好的情况，目标难度在两个相邻的档位之间，直接随机这两个档位即可
                    local _r = randomUpOrLow( upDV, lowDV )
                    if _r == 1 then 
                        if self.debugMode then printx(1,"selfFeedback ---------- random 111 upDV:" , upDV, "diffFix:", upK) end
                        _finalDiffFix = upK 
                        _feedpath = 5
                    else
                        if self.debugMode then printx(1,"selfFeedback ---------- random 111 lowDV:" , lowDV, "diffFix:", lowK) end
                        _finalDiffFix = lowK 
                        _feedpath = 6
                    end

                    local _r2 = math.random()
                    if _r2 < 0.98 then
                        -- to nothing
                        _feedpath = 7
                    elseif _r2 < 0.99 then
                        _finalDiffFix = _finalDiffFix + 1
                        _feedpath = 8
                    else
                        _finalDiffFix = _finalDiffFix - 1
                        _feedpath = 9
                    end
                elseif upK - lowK >= 2 then    

                    if true then
                        local upK_l = nil
                        local upDV_l = nil

                        --[[
                            t     6
                            -10,  1.8   low
                            5,    6.6   up
                        ]]
                        local pt = upK - lowK

                        for ia = lowK + 1 , lowK + (pt - 1) do
                            
                            if _checkmap[ia] and _checkmap[ia] >= desiredDiff then
                                if not upDV_l then
                                    upDV_l = _checkmap[ia] - desiredDiff
                                    upK_l = ia
                                end

                                if _checkmap[ia] - desiredDiff < upDV_l then
                                    upDV_l = _checkmap[ia] - desiredDiff
                                    upK_l = ia
                                end
                            end
                        end

                        local _r = math.random()

                        if self.debugMode then printx(1,"selfFeedback ---------- random 222 _r:" , _r, "pt =" , pt, "upDV_l =" , upDV_l, "upK_l =", upK_l ) end

                        if _r <= 0.5 then
                            -- 【50%几率】只在原始的upK，lowK两档之间随机 

                            local _r2 = randomUpOrLow( upDV, lowDV )
                            if self.debugMode then printx(1,"selfFeedback ---------- random  【50%几率】只在原始的upK, lowK两档之间随机   _r2" , _r2 ) end

                            if _r2 == 1 then 
                                if self.debugMode then printx(1,"selfFeedback ---------- random 222 n1 upDV:" , upDV, "diffFix:", upK) end
                                _finalDiffFix = upK 
                                _feedpath = 10
                            else
                                if self.debugMode then printx(1,"selfFeedback ---------- random 222 n2 lowDV:" , lowDV, "diffFix:", lowK) end
                                _finalDiffFix = lowK 
                                _feedpath = 11
                            end

                        elseif _r <= 0.75 then
                            -- 【25%几率】在“lowK”和“upK，lowK之间的某一个X档位”之间随机 
                            --  X档位的定义是，upK，lowK之间，难度大于desiredDiff，但和desiredDiff的差值最小的档位
                            --  前提是X档位存在
                            if self.debugMode then printx(1,"selfFeedback ---------- random  【25%几率】在“lowK”和“upK，lowK之间的某一个X档位”之间随机   X档位:" , upK_l ) end

                            local _fixUpK = nil
                            local _fixUpDV = nil
                            if upK_l then
                                if self.debugMode then printx(1,"selfFeedback ---------- random  X档位存在  _fixUpK:" , _fixUpK, "_fixUpDV:", _fixUpDV ) end

                                _fixUpK = upK_l
                                _fixUpDV = upDV_l
                                _feedpath = 12
                            else
                                local _r3 = math.random()

                                if self.debugMode then printx(1,"selfFeedback ---------- random  X档位不存在  _r3:" , _r3 ) end

                                if _r3 >= 0.5 then
                                    _fixUpK = upK
                                    _fixUpDV = upDV
                                    _feedpath = 13
                                end
                            end

                            if _fixUpK then
                                local _r2 = randomUpOrLow( _fixUpDV, lowDV )
                                if _r2 == 1 then 
                                    if self.debugMode then printx(1,"selfFeedback ---------- random 222 n3 upDV:" , _fixUpDV, "diffFix:", _fixUpK) end
                                    _finalDiffFix = _fixUpK 
                                    _feedpath = 14
                                else
                                    if self.debugMode then printx(1,"selfFeedback ---------- random 222 n4 lowDV:" , lowDV, "diffFix:", lowK) end
                                    _finalDiffFix = lowK 
                                    _feedpath = 15
                                end
                            else
                                local _r2 = math.random(1, pt-1)
                                if self.debugMode then printx(1,"selfFeedback ---------- random 222 n5  lowK:", lowK, "diffFix:", lowK + _r2) end
                                _finalDiffFix = lowK + _r2
                                _feedpath = 16
                            end
                            
                        else
                            --  【25%几率】在upK，lowK之间随机一个档位（不含upK，lowK）
                            local _r2 = math.random(1, pt-1)
                            if self.debugMode then printx(1,"selfFeedback ---------- random 222 n6  【25%几率】在upK, lowK之间随机一个档位  lowK:", lowK, "diffFix:", lowK + _r2) end
                            _finalDiffFix = lowK + _r2
                            _feedpath = 17
                        end
                    else
                        -----------------------------------------------------------old version

                        --[[
                            5,   4,   3,   2,   1,   0,   -1,   -2,   -3,   -4,   -5
                                                [up]                        [low]
                                                4.5                         2.8         线上数据只有【1档】和【-4档】有值，目标难度4.1
                                                    4.16 3.82   3.48  3.14              假设难度的下降是线性的，进行线性插值，得出空白档位的预测难度
                                                        [tar]                           目标难度4.1，位于【0档】4.16 和 【-1档】3.82 之间
                                                [random 0 ~ -1]                         在0和-1之间随机

                            当【0档】和【-1档】有足够的过关次数后，策略将被自动修正

                            upK = 1
                            upDV = 4.5 - 4.1 = 0.4
                            lowK = -4
                            lowDV = 4.1 - 2.8 = 1.3

                            upV = 4.5
                            lowV = 2.8

                            -----------------------------------------------------------------

                            5,   4,   3,   2,   1,   0,   -1,   -2,   -3,   -4,   -5
                                                [low]                       [up]
                                                2.8                         4.5         线上数据只有【1档】和【-4档】有值，目标难度4.1
                                                    4.16 3.82   3.48  3.14              假设难度的下降是线性的，进行线性插值，得出空白档位的预测难度
                                                        [tar]                           目标难度4.1，位于【0档】4.16 和 【-1档】3.82 之间
                                                [random 0 ~ -1]                         在0和-1之间随机

                            当【0档】和【-1档】有足够的过关次数后，策略将被自动修正

                            upK = -4
                            upDV = 4.5 - 4.1 = 0.4
                            lowK = 1
                            lowDV = 4.1 - 2.8 = 1.3

                            upV = 4.5
                            lowV = 2.8

                        ]]

                        if self.debugMode then printx(1,"selfFeedback ---------- upK =" , upK, "upV =", upV, "lowK =", lowK, "lowV =" , lowV ) end

                        --[[
                            ( 4.5 - 2.8 ) / (1 + 4)
                            _dv = 0.34 
                        ]]
                        local _dv = math.floor( ((upV - lowV) / (upK - lowK)) * 1000 ) / 1000
                        local _list2 = {}
                        local _currV = upV
                        
                        table.insert(_list2, {k = upK, v = upV}) -- k = 1
                        
                        for i = 1 , upK - lowK - 1 do -- i = [1 , 2 , 3 , 4]
                            if _dv > 0 then
                                _currV = _currV - _dv 
                                table.insert(_list2, {k = upK - i, v = _currV}) -- insert k = [ 0, -1, -2, -3 ]
                            else
                                _currV = _currV + _dv
                                table.insert(_list2, {k = upK + i, v = _currV}) -- insert k = [ 0, -1, -2, -3 ]
                            end
                        end

                        table.insert(_list2, {k = lowK, v = lowV}) -- k = -4


                        if self.debugMode then printx(1,"selfFeedback ---------- _list2 =" , tts(_list2) ) end

                        local _result = findUpAndLow(_list2, desiredDiff)
                        upK = _result.upK
                        upDV = _result.upDV
                        lowK = _result.lowK
                        lowDV = _result.lowDV

                        if self.debugMode then printx(1,"selfFeedback ---------- _list2   findUpAndLow  _result =" , tts(_result) ) end

                        local _r = randomUpOrLow( upDV, lowDV )
                        if _r == 1 then 
                            if self.debugMode then printx(1,"selfFeedback ---------- random 222 upDV:" , upDV, "diffFix:", upK) end
                            _finalDiffFix = upK 
                        else
                            if self.debugMode then printx(1,"selfFeedback ---------- random 222 lowDV:" , lowDV, "diffFix:", lowK) end
                            _finalDiffFix = lowK 
                        end
                    end
                elseif upK - lowK <= -2 then --todo

                    local _r = math.random()
                    local pt = lowK - upK

                    if self.debugMode then printx(1,"selfFeedback ---------- random 666 _r:" , _r, "pt =" , pt, "upK =" , upK, "lowK =", lowK ) end

                    if _r <= 0.75 then
                        local _r2 = randomUpOrLow( upDV, lowDV )
                        if _r2 == 1 then 
                            if self.debugMode then printx(1,"selfFeedback ---------- random 666 n1 upDV:" , upDV, "diffFix:", upK) end
                            _finalDiffFix = upK 
                            _feedpath = 18
                        else
                            if self.debugMode then printx(1,"selfFeedback ---------- random 666 n2 lowDV:" , lowDV, "diffFix:", lowK) end
                            _finalDiffFix = lowK 
                            _feedpath = 19
                        end
                    else
                        local _r2 = math.random(1, pt-1)
                        _finalDiffFix = lowK - _r2
                        _feedpath = 20
                        if self.debugMode then printx(1,"selfFeedback ---------- random 666 n3  lowK:", lowK, "diffFix:", _finalDiffFix) end
                    end
                else
                    if self.debugMode then printx(1,"selfFeedback ---------- random pass !!!") end
                    _feedpath = 21
                end
            elseif upK and not lowK then
                local _r = math.random()
                if self.debugMode then printx(1,"selfFeedback ---------- random 333 ", "_r =", _r, "upK =" , upK, "lowK =", lowK) end
                if _r <= 0.4 then
                    _finalDiffFix = upK
                    _feedpath = 22
                    if self.debugMode then printx(1,"selfFeedback ---------- random 333.1 ", "diffFix:", _finalDiffFix) end
                elseif _r <= 0.8 then
                    _finalDiffFix = upK - 1
                    _feedpath = 23
                    if self.debugMode then printx(1,"selfFeedback ---------- random 333.2 ", "diffFix:", _finalDiffFix) end
                else
                    _finalDiffFix = upK - 2
                    _feedpath = 24
                    if self.debugMode then printx(1,"selfFeedback ---------- random 333.3 ", "diffFix:", _finalDiffFix) end
                end
            elseif lowK and not upK then
                local _r = math.random()
                if self.debugMode then printx(1,"selfFeedback ---------- random 444 ", "_r =", _r, "upK =" , upK, "lowK =", lowK) end
                if _r <= 0.4 then
                    _finalDiffFix = lowK
                    _feedpath = 25
                    if self.debugMode then printx(1,"selfFeedback ---------- random 444.1 ", "diffFix:", _finalDiffFix) end
                elseif _r <= 0.8 then
                    _finalDiffFix = lowK + 1
                    _feedpath = 26
                    if self.debugMode then printx(1,"selfFeedback ---------- random 444.2 ", "diffFix:", _finalDiffFix) end
                else
                    _finalDiffFix = lowK + 2
                    _feedpath = 27
                    if self.debugMode then printx(1,"selfFeedback ---------- random 444.3 ", "diffFix:", _finalDiffFix) end
                end
            else
                local selfFeedBackdefaultConfig = require("ubf.metaConfig.ubfuuu_self_feedback_default_config")
                local _defaultDiffFix_topLevel = 2
                if selfFeedBackdefaultConfig then
                    for k,v in ipairs(selfFeedBackdefaultConfig) do
                        if desiredDiff <= v.fixedDesiredDiffAvg then
                            _defaultDiffFix_topLevel = v.defaultDiffFix
                            break
                        end
                    end
                end

                local _r = math.random()
                if self.debugMode then printx(1,"selfFeedback ---------- random 555 ", "_r =", _r, "upK =" , upK, "lowK =", lowK) end
                if _r <= 0.8 then
                    if isTopLevelRange then
                        _finalDiffFix = _defaultDiffFix_topLevel
                        _feedpath = 28
                    else
                        _finalDiffFix = 1
                        _feedpath = 29
                    end
                    if self.debugMode then printx(1,"selfFeedback ---------- random 555.1 ", "diffFix:", _finalDiffFix) end 
                elseif _r <= 0.9 then
                    if isTopLevelRange then
                        _finalDiffFix = _defaultDiffFix_topLevel - 1
                        _feedpath = 30
                    else
                        _finalDiffFix = 0
                        _feedpath = 31
                    end
                    if self.debugMode then printx(1,"selfFeedback ---------- random 555.2 ", "diffFix:", _finalDiffFix) end
                else
                    if isTopLevelRange then
                        _finalDiffFix = _defaultDiffFix_topLevel + 1
                        _feedpath = 32
                    else
                        _finalDiffFix = 2
                        _feedpath = 33
                    end
                    if self.debugMode then printx(1,"selfFeedback ---------- random 555.3 ", "diffFix:", _finalDiffFix) end
                end
            end
        end
        
        if self.debugMode then printx(1,"selfFeedback ---------- oringin  diffFix:", _finalDiffFix) end

        if _finalDiffFix then
            if _finalDiffFix > maxDiffFix then _finalDiffFix = maxDiffFix end
            if _finalDiffFix < minDiffFix then _finalDiffFix = minDiffFix end
        end
    else
        if not _diff_ds_map then
            failReason = UbfuuuDisableReason.kFeedback_NoDiffDsMap
        elseif not desiredDiff then
            failReason = UbfuuuDisableReason.kFeedback_NoDesiredDiff
        end
    end

    if self.debugMode then printx(1,"selfFeedback ---------- fin  _finalDiffFix:", _finalDiffFix) end

    local realDiffAvgByDiffFix = _getDiffAvgInMap(_diff_ds_map, _finalDiffFix)

    local _resultData = {
        diffFix = _finalDiffFix, 
        randomSeed = _randomSeed,
        upK = upK,
        upV = upV,
        upDV = upDV,
        lowK = lowK,
        lowV = lowV,
        lowDV = lowDV,
        feedpath = _feedpath,
        realDiffAvgByDiffFix = realDiffAvgByDiffFix,
        failReason = failReason
    }

    if self.debugMode then printx(1,"selfFeedback ---------- resultData:", tts(_resultData)) end

    return _resultData

end

function UBFuuuSelfFeedback:findStepFixByDesiredStep(levelId, desiredStep, datas, levelScene)

    local _randomSeed = nil

    local _finalStepFix = nil
    local _feedpath = 0

    local usedPreAddStep = 0
    local isTopLevelRange = false

    if datas then
        usedPreAddStep = datas.usedPreAddStep
        _randomSeed = datas.randomSeed or os.time()
        isTopLevelRange = datas.isTopLevelRange 
    else
        _randomSeed = os.time()
    end

    math.randomseed(_randomSeed)

    local UBFuuuAdjustManager = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager"
    local _step_ds_map = UBFuuuAdjustManager:getStepDsMap(levelId, usedPreAddStep, {poolKey = datas.poolKey}, levelScene)
    if not _step_ds_map then _step_ds_map = {} end

    if self.debugMode then 
        if _step_ds_map then  
            --[[
                -10 ~ 0 ~ 5
                {
                    [-10] = {
                        diff_1000 = 6.211,
                        diff_10000 = 2.995,
                        diff_300 = 5.66,
                        diff_all = 2.974,
                        levelExp = "default",
                        levelGroup = "default",
                        levelId = 8611,
                        useAddStep = 0,
                    },
                    [-9] = {
                        diff_1000 = 3.815,
                        diff_10000 = 3.121,
                        diff_300 = 5.769,
                        diff_all = 3.121,
                        levelExp = "default",
                        levelGroup = "default",
                        levelId = 8611,
                        useAddStep = 0,
                    },
                }
            ]]
            printx( 1 , "UBFuuuSelfFeedback:findStepFixByDesiredStep  -------- _step_ds_map =======  ", tts( _step_ds_map ) )  
        else
            printx( 1 , "UBFuuuSelfFeedback:findStepFixByDesiredStep  -------- _step_ds_map =======  nil" )  
        end
    end
    
    if self.debugMode then printx(1,"UBFuuuSelfFeedback:findStepFixByDesiredStep selfFeedback ---------- desiredStep =" , desiredStep, "_step_ds_map = " , _step_ds_map) end
    
    local upK = nil
    local upV = nil
    local upDV = nil
    
    local lowK = nil
    local lowV = nil
    local lowDV = nil

    local UBFuuuSelectAdjust = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuSelectAdjust")
    local _range = UBFuuuSelectAdjust:getStepFixRange()
    local maxStepFix = _range.max
    local minStepFix = _range.min

    if _step_ds_map and desiredStep then
        
        local _checklist = {}
        local _checkmap = {}
        for i = maxStepFix , minStepFix , -1 do
            local istr = tostring(i)
            if _step_ds_map[istr] then
                    -- body
                local _step = _step_ds_map[istr].step

                if _step then
                    table.insert(_checklist, {k=i, v=_step})
                    _checkmap[i] = _step
                end
            end
        end

        if #_checklist > 0 then
            local _result = findUpAndLow(_checklist, desiredStep)

            upK = _result.upK -- 2
            upV = _result.upV
            upDV = _result.upDV -- 40.984 - 12 = 28.984

            lowK = _result.lowK -- 1
            lowV = _result.lowV
            lowDV = _result.lowDV -- 12 - 11.905 = 0.095
        end

        if self.debugMode then printx(1,"UBFuuuSelfFeedback:findStepFixByDesiredStep selfFeedback ---------- upK =" , upK, "upDV =", upDV, "lowK =", lowK, "lowDV =", lowDV ) end

        if upDV == 0 or lowDV == 0 then
            --目标难度 和某个档位的难度 相同，直接使用这个档位
            local _r = math.random()

            if upDV == 0 then
                if self.debugMode then printx(1,"selfFeedback ---------- random 000.1 upDV:" , upDV, "stepFix:", upK) end
                if _r < 0.98 then
                    _finalStepFix = upK 
                    _feedpath = 1
                elseif _r < 0.99 then
                    _finalStepFix = upK + 1
                    _feedpath = 2
                else
                    _finalStepFix = upK - 1
                    _feedpath = 3
                end
            else
                if self.debugMode then printx(1,"selfFeedback ---------- random 000.2 lowDV:" , lowDV, "stepFix:", lowK) end
                _finalStepFix = lowK 
                _feedpath = 4
            end
            
        elseif upK and lowK then
            if math.abs(upK - lowK) == 1 then
                --最好的情况，目标难度在两个相邻的档位之间，直接随机这两个档位即可
                local _r = randomUpOrLow( upDV, lowDV )
                if _r == 1 then 
                    if self.debugMode then printx(1,"selfFeedback ---------- random 111 upDV:" , upDV, "stepFix:", upK) end
                    _finalStepFix = upK 
                    _feedpath = 5
                else
                    if self.debugMode then printx(1,"selfFeedback ---------- random 111 lowDV:" , lowDV, "stepFix:", lowK) end
                    _finalStepFix = lowK 
                    _feedpath = 6
                end

                local _r2 = math.random()
                if _r2 < 0.98 then
                    -- to nothing
                    _feedpath = 7
                elseif _r2 < 0.99 then
                    _finalStepFix = _finalStepFix + 1
                    _feedpath = 8
                else
                    _finalStepFix = _finalStepFix - 1
                    _feedpath = 9
                end
            elseif upK - lowK >= 2 then    

                if true then
                    local upK_l = nil
                    local upDV_l = nil

                    --[[
                        t     6
                        -10,  1.8   low
                        5,    6.6   up
                    ]]
                    local pt = upK - lowK

                    for ia = lowK + 1 , lowK + (pt - 1) do
                        
                        if _checkmap[ia] and _checkmap[ia] >= desiredStep then
                            if not upDV_l then
                                upDV_l = _checkmap[ia] - desiredStep
                                upK_l = ia
                            end

                            if _checkmap[ia] - desiredStep < upDV_l then
                                upDV_l = _checkmap[ia] - desiredStep
                                upK_l = ia
                            end
                        end
                    end

                    local _r = math.random()

                    if self.debugMode then printx(1,"selfFeedback ---------- random 222 _r:" , _r, "pt =" , pt, "upDV_l =" , upDV_l, "upK_l =", upK_l ) end

                    if _r <= 0.5 then
                        -- 【50%几率】只在原始的upK，lowK两档之间随机 

                        local _r2 = randomUpOrLow( upDV, lowDV )
                        if self.debugMode then printx(1,"selfFeedback ---------- random  【50%几率】只在原始的upK, lowK两档之间随机   _r2" , _r2 ) end

                        if _r2 == 1 then 
                            if self.debugMode then printx(1,"selfFeedback ---------- random 222 n1 upDV:" , upDV, "stepFix:", upK) end
                            _finalStepFix = upK 
                            _feedpath = 10
                        else
                            if self.debugMode then printx(1,"selfFeedback ---------- random 222 n2 lowDV:" , lowDV, "stepFix:", lowK) end
                            _finalStepFix = lowK 
                            _feedpath = 11
                        end

                    elseif _r <= 0.75 then
                        -- 【25%几率】在“lowK”和“upK，lowK之间的某一个X档位”之间随机 
                        --  X档位的定义是，upK，lowK之间，难度大于desiredStep，但和desiredStep的差值最小的档位
                        --  前提是X档位存在
                        if self.debugMode then printx(1,"selfFeedback ---------- random  【25%几率】在“lowK”和“upK，lowK之间的某一个X档位”之间随机   X档位:" , upK_l ) end

                        local _fixUpK = nil
                        local _fixUpDV = nil
                        if upK_l then
                            if self.debugMode then printx(1,"selfFeedback ---------- random  X档位存在  _fixUpK:" , _fixUpK, "_fixUpDV:", _fixUpDV ) end

                            _fixUpK = upK_l
                            _fixUpDV = upDV_l
                            _feedpath = 12
                        else
                            local _r3 = math.random()

                            if self.debugMode then printx(1,"selfFeedback ---------- random  X档位不存在  _r3:" , _r3 ) end

                            if _r3 >= 0.5 then
                                _fixUpK = upK
                                _fixUpDV = upDV
                                _feedpath = 13
                            end
                        end

                        if _fixUpK then
                            local _r2 = randomUpOrLow( _fixUpDV, lowDV )
                            if _r2 == 1 then 
                                if self.debugMode then printx(1,"selfFeedback ---------- random 222 n3 upDV:" , _fixUpDV, "stepFix:", _fixUpK) end
                                _finalStepFix = _fixUpK 
                                _feedpath = 14
                            else
                                if self.debugMode then printx(1,"selfFeedback ---------- random 222 n4 lowDV:" , lowDV, "stepFix:", lowK) end
                                _finalStepFix = lowK 
                                _feedpath = 15
                            end
                        else
                            local _r2 = math.random(1, pt-1)
                            if self.debugMode then printx(1,"selfFeedback ---------- random 222 n5  lowK:", lowK, "stepFix:", lowK + _r2) end
                            _finalStepFix = lowK + _r2
                            _feedpath = 16
                        end
                        
                    else
                        --  【25%几率】在upK，lowK之间随机一个档位（不含upK，lowK）
                        local _r2 = math.random(1, pt-1)
                        if self.debugMode then printx(1,"selfFeedback ---------- random 222 n6  【25%几率】在upK, lowK之间随机一个档位  lowK:", lowK, "stepFix:", lowK + _r2) end
                        _finalStepFix = lowK + _r2
                        _feedpath = 17
                    end
                else
                    -----------------------------------------------------------old version

                    --[[
                        5,   4,   3,   2,   1,   0,   -1,   -2,   -3,   -4,   -5
                                            [up]                        [low]
                                            4.5                         2.8         线上数据只有【1档】和【-4档】有值，目标难度4.1
                                                4.16 3.82   3.48  3.14              假设难度的下降是线性的，进行线性插值，得出空白档位的预测难度
                                                    [tar]                           目标难度4.1，位于【0档】4.16 和 【-1档】3.82 之间
                                            [random 0 ~ -1]                         在0和-1之间随机

                        当【0档】和【-1档】有足够的过关次数后，策略将被自动修正

                        upK = 1
                        upDV = 4.5 - 4.1 = 0.4
                        lowK = -4
                        lowDV = 4.1 - 2.8 = 1.3

                        upV = 4.5
                        lowV = 2.8

                        -----------------------------------------------------------------

                        5,   4,   3,   2,   1,   0,   -1,   -2,   -3,   -4,   -5
                                            [low]                       [up]
                                            2.8                         4.5         线上数据只有【1档】和【-4档】有值，目标难度4.1
                                                4.16 3.82   3.48  3.14              假设难度的下降是线性的，进行线性插值，得出空白档位的预测难度
                                                    [tar]                           目标难度4.1，位于【0档】4.16 和 【-1档】3.82 之间
                                            [random 0 ~ -1]                         在0和-1之间随机

                        当【0档】和【-1档】有足够的过关次数后，策略将被自动修正

                        upK = -4
                        upDV = 4.5 - 4.1 = 0.4
                        lowK = 1
                        lowDV = 4.1 - 2.8 = 1.3

                        upV = 4.5
                        lowV = 2.8

                    ]]

                    if self.debugMode then printx(1,"selfFeedback ---------- upK =" , upK, "upV =", upV, "lowK =", lowK, "lowV =" , lowV ) end

                    --[[
                        ( 4.5 - 2.8 ) / (1 + 4)
                        _dv = 0.34 
                    ]]
                    local _dv = math.floor( ((upV - lowV) / (upK - lowK)) * 1000 ) / 1000
                    local _list2 = {}
                    local _currV = upV
                    
                    table.insert(_list2, {k = upK, v = upV}) -- k = 1
                    
                    for i = 1 , upK - lowK - 1 do -- i = [1 , 2 , 3 , 4]
                        if _dv > 0 then
                            _currV = _currV - _dv 
                            table.insert(_list2, {k = upK - i, v = _currV}) -- insert k = [ 0, -1, -2, -3 ]
                        else
                            _currV = _currV + _dv
                            table.insert(_list2, {k = upK + i, v = _currV}) -- insert k = [ 0, -1, -2, -3 ]
                        end
                    end

                    table.insert(_list2, {k = lowK, v = lowV}) -- k = -4


                    if self.debugMode then printx(1,"selfFeedback ---------- _list2 =" , tts(_list2) ) end

                    local _result = findUpAndLow(_list2, desiredStep)
                    upK = _result.upK
                    upDV = _result.upDV
                    lowK = _result.lowK
                    lowDV = _result.lowDV

                    if self.debugMode then printx(1,"selfFeedback ---------- _list2   findUpAndLow  _result =" , tts(_result) ) end

                    local _r = randomUpOrLow( upDV, lowDV )
                    if _r == 1 then 
                        if self.debugMode then printx(1,"selfFeedback ---------- random 222 upDV:" , upDV, "stepFix:", upK) end
                        _finalStepFix = upK 
                    else
                        if self.debugMode then printx(1,"selfFeedback ---------- random 222 lowDV:" , lowDV, "stepFix:", lowK) end
                        _finalStepFix = lowK 
                    end
                end
            elseif upK - lowK <= -2 then --todo

                local _r = math.random()
                local pt = lowK - upK

                if self.debugMode then printx(1,"selfFeedback ---------- random 666 _r:" , _r, "pt =" , pt, "upK =" , upK, "lowK =", lowK ) end

                if _r <= 0.75 then
                    local _r2 = randomUpOrLow( upDV, lowDV )
                    if _r2 == 1 then 
                        if self.debugMode then printx(1,"selfFeedback ---------- random 666 n1 upDV:" , upDV, "stepFix:", upK) end
                        _finalStepFix = upK 
                        _feedpath = 18
                    else
                        if self.debugMode then printx(1,"selfFeedback ---------- random 666 n2 lowDV:" , lowDV, "stepFix:", lowK) end
                        _finalStepFix = lowK 
                        _feedpath = 19
                    end
                else
                    local _r2 = math.random(1, pt-1)
                    _finalStepFix = lowK - _r2
                    _feedpath = 20
                    if self.debugMode then printx(1,"selfFeedback ---------- random 666 n3  lowK:", lowK, "stepFix:", _finalStepFix) end
                end
            else
                if self.debugMode then printx(1,"selfFeedback ---------- random pass !!!") end
                _feedpath = 21
            end
        elseif upK and not lowK then
            local _r = math.random()
            if self.debugMode then printx(1,"selfFeedback ---------- random 333 ", "_r =", _r, "upK =" , upK, "lowK =", lowK) end
            if _r <= 0.4 then
                _finalStepFix = upK
                _feedpath = 22
                if self.debugMode then printx(1,"selfFeedback ---------- random 333.1 ", "stepFix:", _finalStepFix) end
            elseif _r <= 0.8 then
                _finalStepFix = upK - 1
                _feedpath = 23
                if self.debugMode then printx(1,"selfFeedback ---------- random 333.2 ", "stepFix:", _finalStepFix) end
            else
                _finalStepFix = upK - 2
                _feedpath = 24
                if self.debugMode then printx(1,"selfFeedback ---------- random 333.3 ", "stepFix:", _finalStepFix) end
            end
        elseif lowK and not upK then
            local _r = math.random()
            if self.debugMode then printx(1,"selfFeedback ---------- random 444 ", "_r =", _r, "upK =" , upK, "lowK =", lowK) end
            if _r <= 0.4 then
                _finalStepFix = lowK
                _feedpath = 25
                if self.debugMode then printx(1,"selfFeedback ---------- random 444.1 ", "stepFix:", _finalStepFix) end
            elseif _r <= 0.8 then
                _finalStepFix = lowK + 1
                _feedpath = 26
                if self.debugMode then printx(1,"selfFeedback ---------- random 444.2 ", "stepFix:", _finalStepFix) end
            else
                _finalStepFix = lowK + 2
                _feedpath = 27
                if self.debugMode then printx(1,"selfFeedback ---------- random 444.3 ", "stepFix:", _finalStepFix) end
            end
        else
            --[[
            local selfFeedBackdefaultConfig = require("ubf.metaConfig.ubfuuu_self_feedback_default_config")
            local _defaultstepFix_topLevel = 2
            if selfFeedBackdefaultConfig then
                for k,v in ipairs(selfFeedBackdefaultConfig) do
                    if desiredStep <= v.fixedDesiredDiffAvg then
                        _defaultstepFix_topLevel = v.defaultstepFix
                        break
                    end
                end
            end

            local _r = math.random()
            if self.debugMode then printx(1,"selfFeedback ---------- random 555 ", "_r =", _r, "upK =" , upK, "lowK =", lowK) end
            if _r <= 0.8 then
                if isTopLevelRange then
                    _finalStepFix = _defaultstepFix_topLevel
                    _feedpath = 28
                else
                    _finalStepFix = 1
                    _feedpath = 29
                end
                if self.debugMode then printx(1,"selfFeedback ---------- random 555.1 ", "stepFix:", _finalStepFix) end 
            elseif _r <= 0.9 then
                if isTopLevelRange then
                    _finalStepFix = _defaultstepFix_topLevel - 1
                    _feedpath = 30
                else
                    _finalStepFix = 0
                    _feedpath = 31
                end
                if self.debugMode then printx(1,"selfFeedback ---------- random 555.2 ", "stepFix:", _finalStepFix) end
            else
                if isTopLevelRange then
                    _finalStepFix = _defaultstepFix_topLevel + 1
                    _feedpath = 32
                else
                    _finalStepFix = 2
                    _feedpath = 33
                end
                if self.debugMode then printx(1,"selfFeedback ---------- random 555.3 ", "stepFix:", _finalStepFix) end
            end
            --]]

            _finalStepFix = 8
            _feedpath = 34

        end
        
        if self.debugMode then printx(1,"selfFeedback ---------- oringin  stepFix:", _finalStepFix) end

        if _finalStepFix then
            if _finalStepFix > maxStepFix then _finalStepFix = maxStepFix end
            if _finalStepFix < minStepFix then _finalStepFix = minStepFix end
        end
    end

    if self.debugMode then printx(1,"selfFeedback ---------- fin  _finalStepFix:", _finalStepFix) end

    local _resultData = {
        stepFix = _finalStepFix, 
        randomSeed = _randomSeed,
        upK = upK,
        upV = upV,
        upDV = upDV,
        lowK = lowK,
        lowV = lowV,
        lowDV = lowDV,
        feedpath = _feedpath,
    }

    if self.debugMode then printx(1,"selfFeedback ---------- resultData:", tts(_resultData)) end

    return _resultData

end

return UBFuuuSelfFeedback