_G.UBF_NO_REQUIRE_LUA_FLAG()

UBFProductItemDiffChangeLogicV2 = class2( "UBFProductItemDiffChangeLogicV2" , UBFBaseLogic )

UBFProductItemDiffChangeLogicV2.colorLogMapKey = "colorLogMap"
UBFProductItemDiffChangeLogicV2.adjustDataKey = "adjustData"

local FalsifyConfig = nil

local log = nil
--
--


local _getFixedDSForScoreAdjustMap = {
	[-5] = 0,
	[-4] = 0,
	[-3] = 0,
	[-2] = 0,
	[-1] = 0,
	[0] = 0,
	[1] = 0,
	[2] = 0,
	[3] = 0,
	[4] = 0,
	[5] = 0,
	[6] = 0,
	[7] = 1,
	[8] = 1,
	[9] = 1,
	[10] = 2,
	[11] = 2,
	[12] = 3,
	[13] = 4,
	[14] = 5,
	[15] = 0,
	[16] = 0,
	[17] = 0,
	[18] = 0,
	[19] = 0,
	[20] = 0,
}

function UBFProductItemDiffChangeLogicV2:build( createData )
	--推荐方案其实是保持 UBFProductItemDiffChangeLogicV2 的各个方法是无状态的，但为了密集计算时的加速，还是决定将部分数据缓存在self上

    self.gameBoardLogic = createData.gameBoardLogic
    self.contextManager = UBFContextManager:getInstance()
    self.levelContext = self.contextManager:getValue( { UBFConst.ContextType.kLevelContext } ):hold()
	self.ubfuuuLogic = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuDiffLogic")

	--[[
		adjustModEnv = {
			activationTag = 2,
			adjustData = {
				ds = 7,
				levelId = 8202,
				mode = 3,
				modeType = 1,
				reason = "NewReturnAndLowActiveAdjust",
			},
			biLivenessTag = 3,
			diffTag = 0,
			isFirstPlay = false,
			isPayUser = false,
			last60DayPayAmount = 0,
			levelId = 8202,
			levelSupportType = 1,
			maxLevelId = 8505,
			payTag = 1,
			settleMentType = 1,
			startNormalLevel = 8202,
			ubfuuu = true,
			userPayTag = 0,
			userPayTag2 = 0,
		}
	]]
	self.adjustModEnv = createData.adjustModEnv 
	-- if log then log( "UBFProductItemDiffChangeLogicV2:build  createData =" , tts(createData) ) end
end


function UBFProductItemDiffChangeLogicV2:onStartLevel()

	--[[
		adjustModEnv.adjustData = {
			ds = 7,
			levelId = 124,
			mode = 3,
			modeType = 1,
			reason = "NewReturnAndLowActiveAdjust",
		},
	]]
	if log then log( "UBFProductItemDiffChangeLogicV2:onStartLevel  self.adjustModEnv.adjustDat =" , self.adjustModEnv.adjustData ) end

	if not self.adjustModEnv.adjustData then return end

	local adJustRawData = {
		adjustMode = self.adjustModEnv.adjustData.adjustMode,
		tarDiff = self.adjustModEnv.adjustData.tarDiff,
		diffFix = self.adjustModEnv.adjustData.diffFix,
		fuuuChartV3 = self.adjustModEnv.adjustData.fuuuChartV3,

		payTag = self.adjustModEnv.userPayTag2,
		activityTag = self.adjustModEnv.biLivenessTag,

		usedPreAddStep = self.adjustModEnv.usedPreAddStep,
		useOtherPreProp = self.adjustModEnv.useOtherPreProp,
		
		selfFeedbackCollect = self.adjustModEnv.selfFeedbackCollect,
		feedbackSelected = self.adjustModEnv.feedbackSelected,
		upK = self.adjustModEnv.upK,
		lowK = self.adjustModEnv.lowK,
		feedpath = self.adjustModEnv.feedpath,
		
		
		passCollectByUseProp = self.adjustModEnv.passCollectByUseProp,
		
		colorLogMap = {},
		currDs = 0,
		dataset = 0,

		enableUBFuuu = self.adjustModEnv.enableUBFuuu,
		
	}

	if self.adjustModEnv.ubfuuCheckResult then
		adJustRawData.ubfuuCheckResult = self.adjustModEnv.ubfuuCheckResult
		adJustRawData.stepFixEnable = adJustRawData.ubfuuCheckResult.stepFixEnable
		adJustRawData.desiredStep = adJustRawData.ubfuuCheckResult.desiredStep
	end

    self.levelContext:setValue(UBFLevelContext.adjustDataKey, adJustRawData)

	self.ubfuuuLogic:onStartLevel(self.levelContext)

	self:setDataset(nil)
	self:setCurrDS(0)
	
	self.currStepColorNumMap = {}
	self.currStepColorNumList = {}
	self.fixedCurrStepColorNumList = {}
end

function UBFProductItemDiffChangeLogicV2:onEnterWaiting(boardContext)
	self:setDataset(nil)
	self:setCurrDS(0)

	local levelAdjustData = self:getAdjustData()

	if log then log( "UBFProductItemDiffChangeLogicV2:onEnterWaiting  levelAdjustData =" , levelAdjustData ) end

	if levelAdjustData then
		-- local deviation, datas = self.gameBoardLogic:callById( self.gameBoardLogic.fuuuGraphLogicId , "getFuuuDeviation" , true , false )
		if log then _G.UBFuuuDebugCore.showPrintInfo = {} end

		self.ubfuuuLogic:onEnterWaiting(self.gameBoardLogic, self.levelContext)
		
		-- calculate_curr_ds
		local resultData = self.ubfuuuLogic:calculateCurrDs(self.levelContext)

		self.ubfuuuLogic:setCurrDs(self.levelContext, resultData)

		if log then 
			-- if levelAdjustData.enableAdjust then
			-- 	local _str = ""
			-- 	for k,v in ipairs(_G.UBFuuuDebugCore.showPrintInfo) do
			-- 		_str = _str .. v
			-- 	end
			-- 	UBFThreadBridge:sendMainThreadDebugGlobalCall("UBFuuuDebug", "showPrint", _str)
			-- end
			_G.UBFuuuDebugCore.showPrintInfo = {}
		end

		if resultData then
			
			local _dataset = self.ubfuuuLogic:tryGetCurrDatasetByDs(resultData.currDs)
			self:setDataset(_dataset)
			-- levelAdjustData.currDs = _currDs
			self:setCurrDS(resultData.currDs)
		end
		
	end
end

function UBFProductItemDiffChangeLogicV2:getAdjustData()
    local adjustData = self.levelContext:getValue( self.adjustDataKey )
	return adjustData
end

function UBFProductItemDiffChangeLogicV2:getAdjustStepData()
    local moveCountWithRevert = self.levelContext:getValue(UBFConst.ContextType.kLeagueContext).moveCountWithRevert
    local stepContext = self.levelContext:getStepContext(moveCountWithRevert)
    local adjustStepData = stepContext:getValue("adjustData")
    return adjustStepData
end

function UBFProductItemDiffChangeLogicV2:getFixedDSForScoreAdjust()
	local _ds = self:getCurrDS()
    if _ds > 0 then
		return _getFixedDSForScoreAdjustMap[_ds] or 0
	end
end

function UBFProductItemDiffChangeLogicV2:getCurrDS()
	if self:getAdjustData() then
		return self:getAdjustData().currDs
	end
    return 0
end

function UBFProductItemDiffChangeLogicV2:setCurrDS(value)
	-- assert(type(value)=="number","not a num:"..tostring(value)  .. " is ".. type(value))
	if self:getAdjustData() then
		self:getAdjustData().currDs = value
	end
end

function UBFProductItemDiffChangeLogicV2:getDataset()
    return self:getAdjustData() and self:getAdjustData().dataset
end

function UBFProductItemDiffChangeLogicV2:setDataset(value)
	if self:getAdjustData() then
		self:getAdjustData().dataset = value
	end
end

--核心修改入口
function UBFProductItemDiffChangeLogicV2:falsify( boardContext , itemContextList )

    local levelAdjustData = self:getAdjustData()
	if not levelAdjustData then return end
	-- if levelAdjustData.adjustMode ~= "ubf" then return end

    for _ , itemContext in ipairs( itemContextList ) do 
        --这个item可以转便的颜色
        local produceColorList = itemContext:getValue("produceColorList")
        
        --如果有，证明是可以换色的item，任何可以换色的item
        if produceColorList then 
            
            local moveCountWithRevert = self.levelContext:getValue( UBFConst.ContextType.kLeagueContext ).moveCountWithRevert

			if not moveCountWithRevert then
				--
--
--
--

				moveCountWithRevert = 0
			end
            local stepContext = self.levelContext:getStepContext( moveCountWithRevert )
            if not stepContext then
				--
--
--
--

				he_log_error( "UBFDiffChangeError_" .. tostring(moveCountWithRevert) )
				return
			end

            self:tryChangeColor( boardContext , levelAdjustData , stepContext , itemContext , moveCountWithRevert )
            -- local color = produceColorList[1]
            -- itemContext:setColor( color )
        end
        
    end 

end

function UBFProductItemDiffChangeLogicV2:changeColorRuleA( boardContext , maxColorIndex , oringinColorIndex , adjustStepData , dataset )
	local result = {}
	result.result = true
	-- if log then log( "ProductItemDiffChangeLogic:changeColorRuleA  " , maxColorIndex ,oringinColorIndex , cannonType ,  tts(adjustStepData) , tts(dataset)) end


	if maxColorIndex ~= oringinColorIndex then
		local maxColorCount = adjustStepData.resultColorMap[maxColorIndex] or 0
		local ruleA_m = 0
		local ri = 0
		
		for i = 1 , 4 do
			-- if log then log( "i" .. tostring(i) , "maxColorIndex = " , maxColorIndex , "maxColorCount = " , maxColorCount ) end
			-- if log then log( table.tostring(adjustStepData.resultColorMap)) end
			if maxColorCount <= dataset["ruleA_n" .. tostring(i)] then
				ruleA_m = dataset["ruleA_m" .. tostring(i)]
				ri = i
				break
			end
		end
		
		local num1 = 100

		if UBFRandom:calcValue( boardContext:nextSeed( "diffAdjust" ) , 1 , num1 ) <= ruleA_m then
			-- if log then log( "RuleA  return 111  ruleA_m =" , ruleA_m , "result.result =" , result.result) end
			return result
		else
			result.result = false
			result.ruleIndex = ri
			result.m = ruleA_m
			-- if log then log( "RuleA  return 222  ruleA_m =" , ruleA_m , "ruleIndex =" , result.ruleIndex ) end
			return result
		end
	else
		-- if log then log( "ProductItemDiffChangeLogic:changeColorRuleA   maxColorIndex ~= oringinColorIndex !!!!!!!!!!!!!!!!!!!!") end
		result.result = true
		result.isSameColor = true
		result.oringinColorIndex = oringinColorIndex
	end

	return result
end

function UBFProductItemDiffChangeLogicV2:changeColorRuleB( maxColorIndex , colorLogList , dataset )
	
    -- if log then log( "ProductItemDiffChangeLogic:changeColorRuleB 1111" ) end
	local result = {}
	result.result = true

	local startIndex = #colorLogList
	local maxColorCount = 0

	for i = 1 , #colorLogList do
		
		local colorIndex = colorLogList[ startIndex - (i -1) ]
		if colorIndex == maxColorIndex then
			maxColorCount = maxColorCount + 1
		end

		-- if log then log( "ProductItemDiffChangeLogic:changeColorRuleB 222  maxColorCount" , maxColorCount ) end

		local needBreak = false
		local ri = 0 
		for ia = 1 , 4 do
			-- if log then log( "ProductItemDiffChangeLogic:changeColorRuleB 333  i" , i ,dataset["ruleB_n" .. tostring(ia)] - 1 ) end
			if i <= dataset["ruleB_n" .. tostring(ia)] - 1 then
				-- if log then log( "ProductItemDiffChangeLogic:changeColorRuleB 444  maxColorCount" , maxColorCount , dataset["ruleB_m" .. tostring(ia)] - 1 ) end
				if maxColorCount >= dataset["ruleB_m" .. tostring(ia)] then
					-- if log then log( "ProductItemDiffChangeLogic:changeColorRuleB 333  ruleB_m" .. tostring(ia) .. " =" , dataset["ruleB_m" .. tostring(ia)] , "maxColorCount =" , maxColorCount , "Break !!!" ) end
					result.result = false --掉落非maxColor
					result.ruleIndex = ia
					result.maxColorIndex = maxColorIndex
					result.maxColorNum = maxColorCount
					needBreak = true
					break
				end
			end
		end

		if needBreak then
			break
		end
	end

    -- if log then log( "ProductItemDiffChangeLogic:changeColorRuleB result" .. tostring(result) ) end
	return result
end

function UBFProductItemDiffChangeLogicV2:changeColorRuleC( maxColorIndex , dataset , moveCountWithRevert )
	local result = {}
	result.result = true

	for i = 1 , 4 do

		local step = dataset["ruleC_n" .. tostring(i)]
		local maxCount = dataset["ruleC_m" .. tostring(i)]
		local maxColorCountInSomeSteps = 0

		for ia = 1 , step do
            local _stepContext = self.levelContext:getStepContextRawData( moveCountWithRevert - (ia-1) )
			if _stepContext then
				maxColorCountInSomeSteps = maxColorCountInSomeSteps + _stepContext.adjustData.changeColorCount
			end
		end

		if maxColorCountInSomeSteps >= maxCount then

			-- if log then log( "ProductItemDiffChangeLogic:changeColorRuleC 222  maxCount =" , maxCount , "maxColorCountInSomeSteps =" , maxColorCountInSomeSteps , "  Break!!!" ) end

			result.result = false --掉落非maxColor
			result.ruleIndex = i
			result.count = maxColorCountInSomeSteps
			return result 
		end
	end

	return result
end

function UBFProductItemDiffChangeLogicV2:_doChangeColor( itemContext , colorIndex , isMaxColor , adjustStepData , dataset , colorLogList )

	if log then log( "UBFProductItemDiffChangeLogicV2:_doChangeColor   colorIndex:" , colorIndex) end

    itemContext:setColor( colorIndex )

	if isMaxColor then
		adjustStepData.changeColorCount = adjustStepData.changeColorCount + 1
	end
	
	adjustStepData.resultColorMap[colorIndex] = adjustStepData.resultColorMap[colorIndex] + 1

	table.insert( colorLogList , colorIndex )
	if #colorLogList > dataset.ruleB_n4 then
		table.remove( colorLogList , 1 )
	end 

	adjustStepData.dropNum = adjustStepData.dropNum + 1
end

function UBFProductItemDiffChangeLogicV2:_doPassChangeColor( oringinColorIndex , adjustStepData , dataset , colorLogList )
	
    adjustStepData.resultColorMap[oringinColorIndex] = adjustStepData.resultColorMap[oringinColorIndex] + 1

	table.insert( colorLogList , oringinColorIndex )
	if #colorLogList > dataset.ruleB_n4 then
		table.remove( colorLogList , 1 )
	end

	adjustStepData.dropNum = adjustStepData.dropNum + 1
end

function UBFProductItemDiffChangeLogicV2:_doChangeNotMaxColor( 
            boardContext , itemContext , maxColorIndex , oringinColorIndex , produceColorList , adjustStepData , dataset , colorLogList )
	
    -- if log then log( "_doChangeNotMaxColor", maxColorIndex , oringinColorIndex , cannonType, r, c , tts(stepData) , tts(dataset) , tts(colorLogList) ) end
	local colorIndex = nil

	if maxColorIndex ~= oringinColorIndex then

		local colorList = nil

		local randomList = {}
		if produceColorList and #produceColorList > 0 then
			for k,v in ipairs( produceColorList ) do
				if v ~= maxColorIndex then
					table.insert( randomList , v )
				end
			end
		end

		if #randomList > 0 then
			colorIndex = randomList[ UBFRandom:calcValue( boardContext:nextSeed( "diffAdjust" ) , 1 , #randomList ) ]
		end
	end

	if colorIndex then
		self:_doChangeColor( itemContext , colorIndex , false , adjustStepData , dataset , colorLogList )
	else
		self:_doPassChangeColor( oringinColorIndex , adjustStepData , dataset , colorLogList )
	end
end

-- get_curr_step_max_num_color
function UBFProductItemDiffChangeLogicV2:getCurrStepMaxNumColor( boardContext , adjustStepData )
    
    local maxColorIndex = adjustStepData.maxColorIndex

    if maxColorIndex and maxColorIndex > 0 then return maxColorIndex end

    local maxCount = 0
    maxColorIndex = 0

    for color = 1 , 6 do
        
        local list = boardContext:filterItemRawDataListByColor( color , true )
        local _count = #list
        if _count > maxCount then
            maxCount = _count
            maxColorIndex = color
        end
    end

    -- if log then log( "pMaxNumColor  =============" , maxColorIndex ) end
    adjustStepData.maxColorIndex = maxColorIndex
    return maxColorIndex
end

function UBFProductItemDiffChangeLogicV2:countBoardColors( boardContext )
	if boardContext then

		local currStepColorNumMap = {} --棋盘中每个颜色的数量（仅统计可消除的颜色，被覆盖的、不可消除的不统计）
		local currStepColorNumList = {}

		for colorIndex = 1 , 6 do
			local list = boardContext:filterItemRawDataListByColor( colorIndex , true )
			currStepColorNumMap[ colorIndex ] = #list
			table.insert( currStepColorNumList , { colorIndex = colorIndex , count = #list } )
		end

		currStepColorNumMap[0] = 0

		return currStepColorNumMap , currStepColorNumList
	end
end

function UBFProductItemDiffChangeLogicV2:changeColorRuleD( boardContext, fixedCurrStepColorNumList, oringinColorIndex, dataset)
	local result = {}
	result.result = false
	result.oringinColorIndex = oringinColorIndex
	
	local currStepMaxColorCount = 0
	if #fixedCurrStepColorNumList > 0 then
		--列表的最后一位为生成列表时的MaxColorCount，但现在不一定是最多的颜色
		currStepMaxColorCount = fixedCurrStepColorNumList[#fixedCurrStepColorNumList].count 
	end

	local fixedMinColorList = {}
	local fixedMaxColorList = {}
	-- if log then log( "changeColorRuleD  fixedCurrStepColorNumList" , tts(fixedCurrStepColorNumList)  ) end
	-- if log then log( "__falsify tryChangeColor  currStepColorNumMap" , tts(self.currStepColorNumMap)  ) end
	for k,v in ipairs( fixedCurrStepColorNumList ) do
		if v.count >= currStepMaxColorCount then
			table.insert( fixedMaxColorList , v )
		else
			table.insert( fixedMinColorList , v )
		end
	end

	-- if log then log( "fixedMinColorList = " , tts(fixedMinColorList) ) end
	-- if log then log( "fixedMaxColorList = " , tts(fixedMaxColorList) ) end

	local fixedMinColorListLength = #fixedMinColorList
	local fixedMaxColorListLength = #fixedMaxColorList

	-- if log then log( "fixedMinColorList = " , tts(fixedMinColorList) ) end
	-- if log then log( "fixedMaxColorList = " , tts(fixedMaxColorList) ) end

	

	if fixedMinColorListLength == 0 and fixedMaxColorListLength > 0  then
		local colorObj = fixedMaxColorList[ UBFRandom:calcValue( boardContext:nextSeed( "diffAdjust" ) , 1 , fixedMaxColorListLength ) ]
		result.colorIndex = colorObj.colorIndex
		colorObj.count = colorObj.count + 1
		result.result = true
	elseif fixedMaxColorListLength > 0 then
		local minColorWeight = fixedMinColorListLength * dataset.ruleD_weight_a1
		local randomCount = minColorWeight + fixedMaxColorListLength * dataset.ruleD_weight_a2
		local randnum = UBFRandom:calcValue( boardContext:nextSeed( "diffAdjust" ) , 1 , randomCount )
		
		if randnum <= minColorWeight then

			local colorObj = nil

			if fixedMinColorListLength == 1 then
				colorObj = fixedMinColorList[ 1 ]
			else
				local configWeight = dataset[ "ruleD_weight_b" .. tostring(fixedMinColorListLength) ]
				local randList = {}
				local rnum = 0
				for k,v in ipairs(configWeight) do
					rnum = rnum + v
					table.insert( randList , rnum ) 
				end

				local ranresult = UBFRandom:calcValue( boardContext:nextSeed( "diffAdjust" ) , 1 , rnum )
				local resultIndex = nil
				for k,v in ipairs(randList) do
					if ranresult <= v then
						resultIndex = k
						break
					end
				end

				colorObj = fixedMinColorList[ resultIndex ]
			end
			
			if colorObj then
				result.colorIndex = colorObj.colorIndex
				colorObj.count = colorObj.count + 1
				result.result = true
			end
		else
			local colorObj = fixedMaxColorList[ UBFRandom:calcValue( boardContext:nextSeed( "diffAdjust" ) , 1 , fixedMaxColorListLength ) ]
			result.colorIndex = colorObj.colorIndex
			colorObj.count = colorObj.count + 1
			result.result = true
		end
	end

	if result.colorIndex == oringinColorIndex then
		result.isSameColor = true
	end
	

	return result
end

function UBFProductItemDiffChangeLogicV2:tryChangeColor( boardContext , levelAdjustData , stepContext , itemContext , moveCountWithRevert )

	-- if log then log( "UBFProductItemDiffChangeLogicV2:tryChangeColor  mode:" , levelAdjustData.adjustMode , "ds:" ,  levelAdjustData.adjustDs ) end
    local adjustStepData = stepContext:getValue( "adjustData" )

    local produceColorList = itemContext:getValue("produceColorList") --todo
    local itemType = itemContext:getItemType()

    if itemType ~= UBFGameItemType.kAnimal then
        return
    end

	local dataset = self:getDataset()

    local oringinColorIndex = itemContext:getColor()

	-- dataset = self:tryGetCurrDataset( boardContext,levelAdjustData )

	if not dataset then
		-- debug.debug()
		if log then log( "UBFProductItemDiffChangeLogicV2:tryChangeColor()  return        has no dataset ! moveCountWithRevert =" , moveCountWithRevert ) end
		return
	end

	local function checkColorInCannon(color) --需要改为map
		-- local singleDropConfigOfGrid = self:getSingleDropConfigOfGrid(cannonPos.r , cannonPos.c)
		-- if log then log( "=== singleDropConfigOfGrid ", cannonPos.r , cannonPos.c,table.tostring(singleDropConfigOfGrid)) end
		-- if log then log( "=== defaultColorList ", table.tostring(self.context.defaultColorList)) end
		-- if singleDropConfigOfGrid then
		-- 	local colorConfig = singleDropConfigOfGrid[cannonType]
		-- 	if not colorConfig then
		-- 		if log then log( "set to defaultColorList ") end
		-- 		colorConfig = self.context.defaultColorList
		-- 	end

		-- 	if colorConfig then
		-- 		if not colorConfig[color] then
		-- 			return false
		-- 		end
		-- 	end
		-- end
        for k,v in ipairs( produceColorList ) do
            if v == color then return true end
        end

		return false
	end

	local colorLogMap = levelAdjustData.colorLogMap
	
	-- if log then log( "UBFProductItemDiffChangeLogicV2:tryChangeColor  colorLog" , table.tostring0(colorLog) ) end

	local cannonPosKey = itemContext:getItemPosKey()

	if not colorLogMap[cannonPosKey] then
		colorLogMap[cannonPosKey] = {}
	end

	local colorLogList = colorLogMap[cannonPosKey]

	local maxColorIndex = self:getCurrStepMaxNumColor( boardContext , adjustStepData )

	local isAvaliable = checkColorInCannon(maxColorIndex)

	-- if log then log(maxColorIndex,isAvaliable) end


    --todo  local targetMap = isNewRule and self._currStepColorNumMapNew or self._currStepColorNumMapOld 需要迁移

	-- if isAvaliable then
	-- 	if log then log( "UBFProductItemDiffChangeLogicV2:tryChangeColor  maxColorIndex(New) :" , maxColorIndex , "isAvaliable:" , isAvaliable , "cannonPosKey:" , cannonPosKey ) end
	-- else
	-- 	if log then log( "UBFProductItemDiffChangeLogicV2:tryChangeColor  maxColorIndex(New) :" , maxColorIndex , "isAvaliable:" , isAvaliable , "cannonPosKey:" , cannonPosKey ) end
	-- 	maxColorIndex = self:getCurrStepMaxNumColor(false)
	-- 	isAvaliable = checkColorInCannon(maxColorIndex)
	-- 	if log then log(maxColorIndex,isAvaliable) end
	-- 	if log then log( "UBFProductItemDiffChangeLogicV2:tryChangeColor  maxColorIndex(Old) :" , maxColorIndex , "isAvaliable:" , isAvaliable , "cannonPosKey:" , cannonPosKey ) end
	-- end
	local _currDs = self:getCurrDS()

	if not isAvaliable then
		-- if log then log( "UBFProductItemDiffChangeLogicV2:tryChangeColor  no avaliable color in cannon") end
		self:_doPassChangeColor( oringinColorIndex , adjustStepData , dataset , colorLogList )
		return
	end

	local function doPlusColor()

		local result = self:changeColorRuleA( boardContext , maxColorIndex , oringinColorIndex , adjustStepData , dataset )
		-- if log then log(table.tostring0(result)) end
		
        local isSameColor = false
		
        if not result.result then

			self:_doPassChangeColor( oringinColorIndex , adjustStepData , dataset , colorLogList )
			return
		else
			if result.isSameColor then
				-- if log then log( "maxColorIndex == oringinColorIndex , so ignore it") end
				isSameColor = true
			end
		end

		if not isSameColor then
			result = self:changeColorRuleB( maxColorIndex , colorLogList , dataset )
			-- if log then log( "UBFProductItemDiffChangeLogicV2:__falsify changeColorRuleB result" , table.tostring0(result) ) end
			if not result.result then
				-- if true then 
				-- 	if log then log( "UBFProductItemDiffChangeLogicV2:__falsify  NOT MAX BY B  at" , cannonPosKey ) end
				-- 	if log then log( "ruleIndex:" , result.ruleIndex , "maxColorIndex:" , result.maxColorIndex , "maxColorNum:" , result.maxColorNum , "oringinColorIndex:" , oringinColorIndex) end
				-- end
				-- printx( 1 ,"+++ doPlusColor +++   _doChangeNotMaxColor 111 -> " , maxColorIndex , oringinColorIndex, "_currDs = " , _currDs)
				self:_doChangeNotMaxColor( 
                        boardContext , itemContext , maxColorIndex  , oringinColorIndex , produceColorList , adjustStepData , dataset , colorLogList)
				-- if log then log( "--------------------------------------") end
				return
			end

			result = self:changeColorRuleC( maxColorIndex , dataset , moveCountWithRevert )
			if not result.result then
				-- printx( 1 ,"+++ doPlusColor +++   _doChangeNotMaxColor 222 -> " , maxColorIndex , oringinColorIndex, "_currDs = " , _currDs)
				self:_doChangeNotMaxColor( 
                        boardContext , itemContext , maxColorIndex  , oringinColorIndex , produceColorList , adjustStepData , dataset , colorLogList )
				-- if log then log( "UBFProductItemDiffChangeLogicV2:__falsify  NOT MAX BY C" ) end
				-- if log then log( "ruleIndex:" , result.ruleIndex , "changeColorCountInSomeSteps:" , result.count) end
				-- if log then log( "--------------------------------------") end
				return
			end
		end
		

		if isSameColor then
			-- if log then log( "UBFProductItemDiffChangeLogicV2:__falsify  PASS BY Same Color Ignore  oringinColorIndex:" , oringinColorIndex , " oringinColorNum:" , stepContext.resultColorMap[oringinColorIndex] ) end
			self:_doPassChangeColor( oringinColorIndex , adjustStepData , dataset , colorLogList )
		else
			-- if log then log( "UBFProductItemDiffChangeLogicV2:__falsify  doChangeColor  oringinColorIndex" , oringinColorIndex , "  maxColorIndex:" , maxColorIndex , "maxColorNum:"  , stepContext.resultColorMap[maxColorIndex] ) end
			-- printx( 1 ,"+++ doPlusColor +++   maxColorIndex = " , maxColorIndex , "_currDs = " , _currDs)
			self:_doChangeColor( itemContext , maxColorIndex , true , adjustStepData , dataset , colorLogList)
		end
	end

	local function doMinusColor()
		-- if log then log( "doMinusColor()" ) end

		local currStepColorNumMap = nil
		local currStepColorNumList = nil
		local fixedCurrStepColorNumList = nil

		local currFrameId = levelAdjustData.currFrameId

		local ruleEValue = dataset.ruleE or 0

		if currFrameId and self.gameBoardLogic:getCurrLogicFrameIndex() - currFrameId <= ruleEValue then 
		-- if self.currFrameId == self.mainLogic.fallingMatchFrameId then 
			currStepColorNumList = self.currStepColorNumList or {}
			currStepColorNumMap = self.currStepColorNumMap or {}
			fixedCurrStepColorNumList = self.fixedCurrStepColorNumList or {}
			-- if log then log( "__falsify tryChangeColor  currFrameId" , currFrameId , "Use Cache !!!" ) end
		else
			levelAdjustData.currFrameId = self.gameBoardLogic:getCurrLogicFrameIndex()
			currStepColorNumMap , currStepColorNumList = self:countBoardColors( boardContext )

			if not currStepColorNumMap then currStepColorNumMap = {} end
			if not currStepColorNumList then currStepColorNumList = {} end

			self.currStepColorNumMap = currStepColorNumMap
			self.currStepColorNumList = currStepColorNumList

			
			fixedCurrStepColorNumList = {}

			for k,v in pairs( produceColorList ) do

				local founded = false
				for k2,v2 in ipairs( currStepColorNumList ) do
					if v2.colorIndex == v then
						table.insert( fixedCurrStepColorNumList , v2 )
						founded = true
						break
					end
				end

				if not founded then
					table.insert( currStepColorNumList , { colorIndex = v , count = 0 } )
					table.insert( fixedCurrStepColorNumList , { colorIndex = v , count = 0 } )
				end
			end

			table.sort( 
							fixedCurrStepColorNumList , 
							function ( a, b )
								return a.count < b.count
							end
						)

			self.fixedCurrStepColorNumList = fixedCurrStepColorNumList

			-- if log then log( "__falsify tryChangeColor  currFrameId" , currFrameId , "countBoardColors !!! \n" , tts(fixedCurrStepColorNumList) ) end
		end

		local result = self:changeColorRuleD( boardContext, fixedCurrStepColorNumList, oringinColorIndex, dataset)
		-- printx( 1 ,"--- doMinusColor ---   _currDs = ", _currDs, "  result = " , tts(result))

		local isSameColor = false
		if not result.result then
			-- if log then log( "__falsify tryChangeColor  _doPassChangeColor 1 at " , cannonPosKey ) end
			self:_doPassChangeColor( oringinColorIndex , adjustStepData , dataset , colorLogList )
		elseif result.colorIndex and result.colorIndex > 0 and (not result.isSameColor) then

			local ruleBResult = self:changeColorRuleB( result.colorIndex , colorLogList , dataset )
			-- printx( 1 ,"--- doMinusColor ---   ruleBResult = " , tts(ruleBResult))

			if ruleBResult.result then
				-- if log then log( "__falsify tryChangeColor  _doChangeColor 2 at " , cannonPosKey , "result.colorIndex =" , result.colorIndex ) end
				-- printx( 1 ,"--- doMinusColor ---   result.colorIndex = " , result.colorIndexs , "_currDs = " , _currDs)
				self:_doChangeColor( itemContext , result.colorIndex , false , adjustStepData , dataset , colorLogList)
			else
				-- if log then log( "__falsify tryChangeColor  _doPassChangeColor 2 at " , cannonPosKey ) end
				self:_doPassChangeColor( oringinColorIndex , adjustStepData , dataset , colorLogList )
			end
		else
			-- if log then log( "__falsify tryChangeColor  _doPassChangeColor 3 at " , cannonPosKey ) end
			self:_doPassChangeColor( oringinColorIndex , adjustStepData , dataset , colorLogList )
		end
	end

	
	-- printx( 1 ," _currDs = ", _currDs)

	if _currDs > 0 then
		doPlusColor()
	elseif _currDs < 0 then
		doMinusColor()
	end
    

	-- if log then log( "UBFProductItemDiffChangeLogicV2 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ mode =" , mode) end
	-- if log then log( table.tostring(stepContext.resultColorMap)) end
end

