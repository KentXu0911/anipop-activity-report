UBFuuuSLRuntimeAdjustLogic = class2("UBFuuuSLRuntimeAdjustLogic", UBFBaseLogic)



function UBFuuuSLRuntimeAdjustLogic:setSelfFeedbackEnableFlag(sourceName, enableFlag)
    if not self.ubfuuuAdjustFixInfo then self.ubfuuuAdjustFixInfo = {} end
    if not self.ubfuuuAdjustFixInfo[UBFuuuFixType.kSelfFeedbackEnableFlag] then self.ubfuuuAdjustFixInfo[UBFuuuFixType.kSelfFeedbackEnableFlag] = {} end
    self.ubfuuuAdjustFixInfo[UBFuuuFixType.kSelfFeedbackEnableFlag].sourceName = sourceName
    self.ubfuuuAdjustFixInfo[UBFuuuFixType.kSelfFeedbackEnableFlag].enableFlag = enableFlag
end


function UBFuuuSLRuntimeAdjustLogic:setSelfFeedbackPoolkey(sourceName, selectKey, collectKey)
    if not self.ubfuuuAdjustFixInfo then self.ubfuuuAdjustFixInfo = {} end
    if not self.ubfuuuAdjustFixInfo[UBFuuuFixType.kSelfFeedbackPoolkey] then self.ubfuuuAdjustFixInfo[UBFuuuFixType.kSelfFeedbackPoolkey] = {} end
    
    if self.ubfuuuAdjustFixInfo[UBFuuuFixType.kSelfFeedbackPoolkey].sourceName then
        self.ubfuuuAdjustFixInfo[UBFuuuFixType.kSelfFeedbackPoolkey].sourceName = self.ubfuuuAdjustFixInfo[UBFuuuFixType.kSelfFeedbackPoolkey].sourceName .. "_" .. sourceName
    else
        self.ubfuuuAdjustFixInfo[UBFuuuFixType.kSelfFeedbackPoolkey].sourceName = sourceName
    end

    if selectKey then
        self.ubfuuuAdjustFixInfo[UBFuuuFixType.kSelfFeedbackPoolkey].selectKey = selectKey
    end
    if collectKey then
        self.ubfuuuAdjustFixInfo[UBFuuuFixType.kSelfFeedbackPoolkey].collectKey = collectKey
    end
end

--[[
    替换指定的UBFuuu调节配置表的源文件
    ubfuuuConfigNameId  配置表的索引id，枚举在 _G.UBFuuuConfigNameId 中
    replaceConfigName   文件名，会用 replaceConfigName 拼接 “_config.lua” 来尝试寻找配置，能找到就替换
]]
function UBFuuuSLRuntimeAdjustLogic:replaceUBFuuuConfigFile(sourceName, ubfuuuConfigNameId, replaceConfigName)
    if not self.ubfuuuAdjustFixInfo then self.ubfuuuAdjustFixInfo = {} end
    if not self.ubfuuuAdjustFixInfo[UBFuuuFixType.kReplaceUBFuuuConfigFile] then self.ubfuuuAdjustFixInfo[UBFuuuFixType.kReplaceUBFuuuConfigFile] = {} end
    self.ubfuuuAdjustFixInfo[UBFuuuFixType.kReplaceUBFuuuConfigFile][tostring(ubfuuuConfigNameId)] = {
        sourceName = sourceName,
        configName = replaceConfigName,
    }
end

function UBFuuuSLRuntimeAdjustLogic:_updatUbfuuuAdjustFixInfo(dataKey, sourceName, fixValue, fixMode, datas)
    if not self.ubfuuuAdjustFixInfo then self.ubfuuuAdjustFixInfo = {} end
    if not self.ubfuuuAdjustFixInfo[dataKey] then self.ubfuuuAdjustFixInfo[dataKey] = {} end
    if not datas then datas = {} end
    local _data = {
        sourceName = sourceName,
        value = fixValue or 0,
        fixMode = fixMode or UBFuuuFixMode.kaddVaule,
        rangeMin = datas.rangeMin,         --原始值不小于rangeMin，才会按fixMode尝试修改
        rangeMax = datas.rangeMax,         --原始值不大于rangeMax，才会按fixMode尝试修改
        resultMin = datas.resultMin,       --原始值如果大于等于resultMin，被fixMode尝试修改后，结果值小于resultMin时，会被重置为resultMin；如果原始值小于resultMin，则不做处理
        resultMax = datas.resultMax,       --原始值如果小于等于resultMax，被fixMode尝试修改后，结果值大于resultMax时，会被重置为resultMax；如果原始值大于resultMax，则不做处理
        minValue = datas.minValue,         --结果值不能小于minValue，否则会被重置为minValue
        maxValue = datas.maxValue,         --结果值不能大于maxValue，否则会被重置为maxValue
        stringValue = datas.stringValue,
    }

    if fixValue then
        if type(fixValue) == "number" then
            _data.value = fixValue
        else
            _data.value = 0
            _data.stringValue = tostring(fixValue)
        end
    end
    
    
    table.insert(self.ubfuuuAdjustFixInfo[dataKey], _data)
end

--[[
-- 更新难度调节的篡改逻辑，篡改 预期步数
]]
function UBFuuuSLRuntimeAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredStep(sourceName, desiredStep, fixMode, datas)
    self:_updatUbfuuuAdjustFixInfo(UBFuuuFixType.kDesiredStep, sourceName, desiredStep, fixMode, datas)
end

--[[
-- 更新难度调节的篡改逻辑，篡改 StepFix
]]
function UBFuuuSLRuntimeAdjustLogic:updateUbfuuuAdjustFixInfoByStepFix(sourceName, stepFix, fixMode, datas)
    self:_updatUbfuuuAdjustFixInfo(UBFuuuFixType.kStepFix, sourceName, stepFix, fixMode, datas)
end

--[[
-- 更新难度调节的篡改逻辑，篡改 活跃指数
-- sourceName，来源名称，标识谁在调用此接口，打点用。活动的话默认传actId
-- diffIndex， 要篡改的值
-- fixMode，篡改类型，枚举值为: UBFuuuFixMode.kSetVaule, UBFuuuFixMode.kaddVaule
]]
function UBFuuuSLRuntimeAdjustLogic:updateUbfuuuAdjustFixInfoByActivityIndex(sourceName, activityIndex, fixMode, datas)
    self:_updatUbfuuuAdjustFixInfo(UBFuuuFixType.kActivityIndex, sourceName, activityIndex, fixMode, datas)
end

--[[
-- 更新难度调节的篡改逻辑，篡改 付费指数
-- sourceName，来源名称，标识谁在调用此接口，打点用。活动的话默认传actId
-- diffIndex， 要篡改的值
-- fixMode，篡改类型，枚举值为: UBFuuuFixMode.kSetVaule, UBFuuuFixMode.kaddVaule
]]
function UBFuuuSLRuntimeAdjustLogic:updateUbfuuuAdjustFixInfoByPaymentIndex(sourceName, paymentIndex, fixMode, datas)
    self:_updatUbfuuuAdjustFixInfo(UBFuuuFixType.kPaymentIndex, sourceName, paymentIndex, fixMode, datas)
end


--[[
-- 更新难度调节的篡改逻辑，篡改 难度指数
-- sourceName，来源名称，标识谁在调用此接口，打点用。活动的话默认传actId
-- diffIndex， 要篡改的值
-- fixMode，篡改类型，枚举值为: UBFuuuFixMode.kSetVaule, UBFuuuFixMode.kaddVaule
]]
function UBFuuuSLRuntimeAdjustLogic:updateUbfuuuAdjustFixInfoByDiffIndex(sourceName, diffIndex, fixMode, datas)
    self:_updatUbfuuuAdjustFixInfo(UBFuuuFixType.kDiffIndex, sourceName, diffIndex, fixMode, datas)
end

--[[
-- 更新难度调节的篡改逻辑，篡改 保底前生效预期难度
-- sourceName，来源名称，标识谁在调用此接口，打点用。活动的话默认传actId
-- desiredDiffAvgBeforeBaodi， 要篡改的值
-- fixMode，篡改类型，枚举值为: UBFuuuFixMode.kSetVaule, UBFuuuFixMode.kaddVaule
]]
function UBFuuuSLRuntimeAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredDiffAvgBeforeBaodi(sourceName, desiredDiffAvgBeforeBaodi, fixMode, datas)
    self:_updatUbfuuuAdjustFixInfo(UBFuuuFixType.kDesiredDiffAvgBeforeBaodi, sourceName, desiredDiffAvgBeforeBaodi or 1, fixMode, datas)
end

--[[
-- 更新难度调节的篡改逻辑，篡改 生效预期难度
-- sourceName，来源名称，标识谁在调用此接口，打点用。活动的话默认传actId
-- fixedDesiredDiffAvg， 要篡改的值
-- fixMode，篡改类型，枚举值为: UBFuuuFixMode.kSetVaule, UBFuuuFixMode.kaddVaule
]]
function UBFuuuSLRuntimeAdjustLogic:updateUbfuuuAdjustFixInfoByFixedDesiredDiffAvg(sourceName, fixedDesiredDiffAvg, fixMode, datas)
    self:_updatUbfuuuAdjustFixInfo(UBFuuuFixType.kFixedDesiredDiffAvg, sourceName, fixedDesiredDiffAvg or 1, fixMode, datas)
end

--[[
-- 更新难度调节的篡改逻辑，篡改 难度偏移档位 DiffFix
-- sourceName，来源名称，标识谁在调用此接口，打点用。活动的话默认传actId
-- fixedDesiredDiffAvg， 要篡改的值
-- fixMode，篡改类型，枚举值为: UBFuuuFixMode.kSetVaule, UBFuuuFixMode.kaddVaule
]]
function UBFuuuSLRuntimeAdjustLogic:updateUbfuuuAdjustFixInfoByDiffFix(sourceName, diffFix, fixMode, datas)
    self:_updatUbfuuuAdjustFixInfo(UBFuuuFixType.kDiffFix, sourceName, diffFix, fixMode, datas)
end

--[[
-- 更新难度调节的篡改逻辑，篡改 加步数时的干预逻辑
-- sourceName，来源名称，标识谁在调用此接口，打点用。活动的话默认传actId
-- addSteps， 增加的步数里（不含前置加三步），多少步之内，需要执行干预
-- addStepAdjustMode，篡改类型，枚举值为: UBFuuuAddStepAdjustMode
]]
local function normalizeAddStepIntervalAvailableSteps(value)
    if type(value) ~= "number" then
        return nil
    end

    if value < 0 then
        return 0
    end

    return math.floor(value)
end

local function normalizeAddStepIntervalAdjustMode(value, defaultValue)
    if value == UBFuuuAddStepAdjustMode.kDoNothing
        or value == UBFuuuAddStepAdjustMode.kLockLastDs
        or value == UBFuuuAddStepAdjustMode.kAddMaxDiffMoveByStep
        or value == UBFuuuAddStepAdjustMode.kAddMaxDiffMoveByFixedValue
        or value == UBFuuuAddStepAdjustMode.kLockMaxDiffMove then
        return value
    end

    return defaultValue
end

local function normalizeAddStepIntervalTargetMaxdiffMove(value)
    if type(value) == "number" then
        return value
    end

    return nil
end

local function buildAddStepIntervalFixRow(sourceName, configOrAvailableSteps, defaultAdjustMode, targetMaxdiffMove, stackingPreValue)
    local intervalConfig = type(configOrAvailableSteps) == "table" and configOrAvailableSteps or nil
    local availableSteps = intervalConfig and intervalConfig.availableSteps or configOrAvailableSteps
    local addStepAdjustMode = defaultAdjustMode
    if intervalConfig and intervalConfig.addStepAdjustMode ~= nil then
        addStepAdjustMode = intervalConfig.addStepAdjustMode
    end

    if addStepAdjustMode == nil then
        addStepAdjustMode = UBFuuuAddStepAdjustMode.kAddMaxDiffMoveByStep
    end

    local finalTargetMaxdiffMove = targetMaxdiffMove
    if intervalConfig and intervalConfig.targetMaxdiffMove ~= nil then
        finalTargetMaxdiffMove = intervalConfig.targetMaxdiffMove
    end

    local finalStackingPreValue = stackingPreValue
    if intervalConfig and intervalConfig.stackingPreValue ~= nil then
        finalStackingPreValue = intervalConfig.stackingPreValue
    end

    return {
        sourceName = sourceName,
        addStepAdjustMode = normalizeAddStepIntervalAdjustMode(addStepAdjustMode, defaultAdjustMode or UBFuuuAddStepAdjustMode.kAddMaxDiffMoveByStep),
        targetMaxdiffMove = normalizeAddStepIntervalTargetMaxdiffMove(finalTargetMaxdiffMove),
        availableSteps = normalizeAddStepIntervalAvailableSteps(availableSteps),
        stackingPreValue = finalStackingPreValue == true,
    }
end

function UBFuuuSLRuntimeAdjustLogic:updateUbfuuuAdjustFixInfoByAddStep(sourceName, addSteps, addStepAdjustMode)
    if not self.ubfuuuAdjustFixInfo then
        self.ubfuuuAdjustFixInfo = {}
    end

    local availableSteps = 1
    if type(addSteps) == "number" then
        -- 这里的 addSteps 已经是“需要覆盖多少步”的计数，新模型消费端使用 stepIndex < availableSteps，
        -- 因此写入时不能再额外 +1，否则 legacy 迁移后的后置区间会多生效一轮。
        availableSteps = math.max(0, math.floor(addSteps))
    end

    self.ubfuuuAdjustFixInfo[UBFuuuFixType.kAddStepFix] = nil
    self.ubfuuuAdjustFixInfo[UBFuuuFixType.kPreAddStepIntervalFix] = buildAddStepIntervalFixRow(
        sourceName,
        nil,
        UBFuuuAddStepAdjustMode.kAddMaxDiffMoveByStep,
        nil,
        false
    )
    self.ubfuuuAdjustFixInfo[UBFuuuFixType.kPostAddStepIntervalFix] = buildAddStepIntervalFixRow(
        sourceName,
        availableSteps,
        addStepAdjustMode or UBFuuuAddStepAdjustMode.kDoNothing,
        nil,
        false
    )

    return self.ubfuuuAdjustFixInfo[UBFuuuFixType.kPostAddStepIntervalFix]
end

function UBFuuuSLRuntimeAdjustLogic:updateUbfuuuAdjustFixInfoByPreAddStepInterval(sourceName, configOrAvailableSteps, addStepAdjustMode, targetMaxdiffMove, stackingPreValue)
    if not self.ubfuuuAdjustFixInfo then
        self.ubfuuuAdjustFixInfo = {}
    end

    self.ubfuuuAdjustFixInfo[UBFuuuFixType.kPreAddStepIntervalFix] = buildAddStepIntervalFixRow(
        sourceName,
        configOrAvailableSteps,
        addStepAdjustMode,
        targetMaxdiffMove,
        stackingPreValue
    )

    return self.ubfuuuAdjustFixInfo[UBFuuuFixType.kPreAddStepIntervalFix]
end

function UBFuuuSLRuntimeAdjustLogic:updateUbfuuuAdjustFixInfoByPostAddStepInterval(sourceName, configOrAvailableSteps, addStepAdjustMode, targetMaxdiffMove, stackingPreValue)
    if not self.ubfuuuAdjustFixInfo then
        self.ubfuuuAdjustFixInfo = {}
    end

    self.ubfuuuAdjustFixInfo[UBFuuuFixType.kPostAddStepIntervalFix] = buildAddStepIntervalFixRow(
        sourceName,
        configOrAvailableSteps,
        addStepAdjustMode,
        targetMaxdiffMove,
        stackingPreValue
    )

    return self.ubfuuuAdjustFixInfo[UBFuuuFixType.kPostAddStepIntervalFix]
end


-- 获取本次进关流程中的Ubfuuu调节篡改信息。注意：返回调用时的状态，调用时机不同，结果可能不同
function UBFuuuSLRuntimeAdjustLogic:getUbfuuuAdjustFixInfo()
    return self.ubfuuuAdjustFixInfo
end
