_G.UBF_NO_REQUIRE_LUA_FLAG()

-- fuuu的调整逻辑
UBFBoardInitAdjustLogic = class2( "UBFBoardInitAdjustLogic" , UBFBaseLogic )

local seedKey = "BoardInitAdjust"
local modeCount = 9
local patternConfig = nil

local _needLog = false
--
--


function UBFBoardInitAdjustLogic:build(createData)
    self.gameBoardLogic = createData.gameBoardLogic
    self.levelContext = UBFContextManager:getInstance():getValue({ UBFConst.ContextType.kLevelContext }):hold()
end


function UBFBoardInitAdjustLogic:beforeBoardColorInit(boardContext)
    if _needLog then printx( 1 , "UBFBoardInitAdjustLogic:beforeBoardColorInit .......... " ) end
    local gEnv = self.levelContext:getValue( UBFLevelContext.gameEnvKey )
    local _adjustData = gEnv.adjustData
    if not _adjustData then 
        if _needLog then printx( 1 , "UBFBoardInitAdjustLogic:beforeBoardColorInit return 1 " ) end
        return 
    end

    if not _adjustData.useBoardInitAdjust then
        if _needLog then printx( 1 , "UBFBoardInitAdjustLogic:beforeBoardColorInit return 2 " ) end
        return
    end

    local result, selectData, allResultList = self:tryChangeBoardByVirtualSeed(_adjustData)
    
    if _needLog then printx( 1 , "UBFBoardInitAdjustLogic:beforeBoardColorInit    result, selectData, allResultList =", result, selectData, allResultList ) end
    
    if result then 
        if _needLog then printx( 1 , "UBFBoardInitAdjustLogic:beforeBoardColorInit ------- selectData =" , tts(selectData) ) end
        self:doChangeBoardByVirtualSeed(selectData)
    end
end

function UBFBoardInitAdjustLogic:tryChangeBoardByVirtualSeed(adjustData)
    
    if adjustData then
        if adjustData.mode == ProductItemDiffChangeMode.kAddColor then
            if adjustData.ds == 7 then
                return self:_tryChangeBoardByVirtualSeed(adjustData.ds, false)
            end
        -- elseif adjustData.mode == ProductItemDiffChangeMode.kAld2023 then
        --     if adjustData.ds >= 15 then
        --         return self:_tryChangeBoardByVirtualSeed(9 - (20 - adjustData.ds), false)
        --     end
        end
    end

    return false
end

--[[
    ds     强度，一共9级
    lockDs 锁定强度，即不降级，指定ds随机不到，就放弃
]]
function UBFBoardInitAdjustLogic:_tryChangeBoardByVirtualSeed(ds, lockDs)
    
    local resultData = nil
    local resultPosList = nil
    
    local boardContext = self.levelContext:getBoardContext(1)
    local boardBorder = boardContext:getBoardBorder(true)

    local seed = nil

    require "zoo.gamePlay.config.GameInitDiffChangeLogicPatternConfig"
    patternConfig = GameInitDiffChangeLogicPatternConfig
	-- local mode = self.mode
	-- local lockDs = false --是否锁定到某一级mode，即不会自动降级
	local onlyCheck = false --只检测并返回结果，并不真正干预

	local usedLogMap = nil

	
    if _needLog then
        printx( 1 , "=====================================================================================================")
        printx( 1 , "=====================================================================================================")
        printx( 1 , "=====================================================================================================")
        printx( 1 , "=======================UBFBoardInitAdjustLogic:tryChangeBoardByVirtualSeed===========================")
        printx( 1 , "=====================================================================================================")
        printx( 1 , "=====================================================================================================")
        printx( 1 , "=====================================================================================================")
    end


	local canRandomColorfulList = {}
	local canRandomColorfulMap = {}

	local itemAroundMap = {}

	for r = boardBorder.top, boardBorder.bottom do 
		for c = boardBorder.left, boardBorder.right do

            local gridRaw = boardContext:getGridRawDataByPos(r, c)
            local itemRaw = gridRaw.itemMaster

            -- isColorful

			if itemRaw then
				if itemRaw.isColorful
					-- and itemRaw.itemType == UBFGameItemType.kAnimal 
					and itemRaw.color == 0
					then

					table.insert(canRandomColorfulList , itemRaw)
					canRandomColorfulMap[gridRaw.posKey] = itemRaw
				end
			end
		end
	end

	if _needLog then printx( 1 , "#canRandomColorfulList " , #canRandomColorfulList ) end
	if #canRandomColorfulList > 0 then

		for ia = 1 , #canRandomColorfulList do

			local itemRaw = canRandomColorfulList[ia] --交换对象A
			local gridRaw = boardContext:getGridRawDataByPos(itemRaw.pos.r, itemRaw.pos.c) --交换对象A所在格子

			if itemRaw and (not gridRaw.isBlockSwap) then

				local mapTable = {}
				mapTable.r = itemRaw.pos.r
				mapTable.c = itemRaw.pos.c
				mapTable.posKey = gridRaw.posKey
				mapTable.aroundMap = {}

				table.insert(itemAroundMap, mapTable)

				local function buildMapTable(rf, cf)

					local aroundPosKey = (mapTable.r + rf - 4) * MACRO_POS_STRIDE + (mapTable.c + cf - 4)

					if canRandomColorfulMap[aroundPosKey] then
						mapTable.aroundMap[ rf * MACRO_POS_STRIDE + cf ] = true
					end
				end

				for ib = 1 , 7 do
					for ic = 1 , 7 do
						if (ib ~= 4 or ic ~= 4) and math.abs(ib - 4) + math.abs(ic - 4) <= 3 then --曼哈顿距离小于等于3，菱形
							buildMapTable( ib , ic )
						end
					end
				end
                if _needLog then 
                    printx( 1, "mapTable ---- " , itemRaw.pos.r,itemRaw.pos.c,gridRaw.posKey )
                    printx( 1, "mapTable.aroundMap =" , tts(mapTable.aroundMap) )
                end
			end
		end

	end

	if not onlyCheck then --检测模式无需随机，因为它将遍历所有组合，不会中途跳出
		----[[
		local randomItemAroundMapIndex = {}
		local randomItemAroundMap = {}

		for i = 1 , #itemAroundMap do
			table.insert( randomItemAroundMapIndex , i )
		end

		for i = 1 , #itemAroundMap do
			local ridx = UBFRandom:calcValue( boardContext:nextSeed(seedKey) , 1 , #randomItemAroundMapIndex )
			table.insert( randomItemAroundMap , itemAroundMap[randomItemAroundMapIndex[ridx]] )
			table.remove( randomItemAroundMapIndex , ridx )
		end

		itemAroundMap = randomItemAroundMap
		--]]
	end

	resultPosList = {}
	local selectMode = ds --预期要匹配的模式（1~9）

	local function tryFind(modeIndex)

		local configList = patternConfig["mode" .. tostring(modeIndex)]

		if not configList then 
			return false
		end

		if not onlyCheck then --检测模式无需随机，因为它将遍历所有组合，不会中途跳出
			----[[
			local randomConfigListIndex = {}
			local randomConfigList = {}

			for i = 1 , #configList do
				table.insert( randomConfigListIndex , i )
			end

			for i = 1 , #configList do
				local ridx = UBFRandom:calcValue( boardContext:nextSeed(seedKey) , 1 , #randomConfigListIndex )
				local rconfig = {}
				rconfig.realIndex = randomConfigListIndex[ridx]
				rconfig.datas = configList[rconfig.realIndex]
				table.insert( randomConfigList , rconfig )
				table.remove( randomConfigListIndex , ridx )
			end

			configList = randomConfigList
			--]]
		end
		
		for k,v in ipairs(itemAroundMap) do

			if _needLog then printx( 1 , "UBFBoardInitAdjustLogic  tryFind  modeIndex:" , modeIndex , "k:", k) end
			--local centerPos = string.split( k , "_")
			local centerR = v.r
			local centerC = v.c
			
			local aroundItemList = v.aroundMap

			for i = 1 , #configList do
				local result = true
				local config = nil
				local realIndex = i

				if onlyCheck then
					config = configList[i]
					realIndex = i
				else
					config = configList[i].datas
					realIndex = configList[i].realIndex
				end
				if _needLog then printx( 1 , "UBFBoardInitAdjustLogic  tryFind   index -------" , i) end
				for k1,v1 in ipairs(config) do
					

					local poskey = v1.dr * MACRO_POS_STRIDE + v1.dc --相对坐标，4,4点为起点
					-- printx( 1 , "UBFBoardInitAdjustLogic  tryFind aroud  poskey:" , poskey)

					if not aroundItemList[poskey] then
						-- printx( 1 , "tryFind  break 1")
						result = false
						break
					end

					if v1.itemB then --是否为交换对象B
						

						--local pos = string.split( k1 , "_")
						local r = centerR + v1.dr - 4
						local c = centerC + v1.dc - 4

						if _needLog then printx( 1 , "UBFBoardInitAdjustLogic  tryFind 交换对象B ---------  " , r , c) end

                        local gridContext_A = boardContext:getGridContextByPos(centerR, centerC)
                        local gridContext_B = boardContext:getGridContextByPos(r, c)

						if gridContext_A and gridContext_B then

							if not gridContext_B:getBlockSwap() then

								if centerR > r and centerC == c then
									if gridContext_A:hasBorderSwapBlocker( UBFDirection.kUp ) then
										if _needLog then printx( 1 , "tryFind  break 2") end
										result = false
                                        gridContext_A:release()
                                        gridContext_B:release()
										break
									end
								elseif centerR < r and centerC == c then
									if gridContext_A:hasBorderSwapBlocker( UBFDirection.kDown ) then
										if _needLog then printx( 1 , "tryFind  break 3") end
										result = false
                                        gridContext_A:release()
                                        gridContext_B:release()
										break
									end
								elseif centerR == r and centerC > c then
									if gridContext_A:hasBorderSwapBlocker( UBFDirection.kLeft ) then
										if _needLog then printx( 1 , "tryFind  break 4") end
										result = false
                                        gridContext_A:release()
                                        gridContext_B:release()
										break
									end
								elseif centerR == r and centerC < c then
									if gridContext_A:hasBorderSwapBlocker( UBFDirection.kRight ) then
										if _needLog then printx( 1 , "tryFind  break 5") end
										result = false
                                        gridContext_A:release()
                                        gridContext_B:release()
										break
									end
								else
									if _needLog then printx( 1 , "tryFind  break 6") end
									if onlyCheck then
										CommonTip:showTip( "UBFBoardInitAdjustLogicPatternConfig ERROR !!!" , "negative", nil, 300)
									end
									assert(false, "UBFBoardInitAdjustLogic  patternConfig config Error ! modeIndex:" .. tostring(modeIndex) .. " " .. tostring(i) )
									result = false
                                    gridContext_A:release()
                                    gridContext_B:release()
									break
								end
							else
								if _needLog then printx( 1 , "tryFind  break 7") end
								result = false
                                gridContext_A:release()
                                gridContext_B:release()
								break
							end
						else
							if _needLog then printx( 1 , "tryFind  break 8") end
							result = false
                            if gridContext_A then gridContext_A:release() end
                            if gridContext_B then gridContext_B:release() end
							break
						end
					end
				end

				if result then
					if _needLog then printx( 1 , "UBFBoardInitAdjustLogic:tryChangeBoardByVirtualSeed result :" , k , "mode" .. tostring(modeIndex) .. "_" .. tostring(i) ) end
					table.insert( resultPosList , { centerR = centerR , centerC = centerC , oringinTypeIndex = ds , typeIndex = modeIndex , patternIndex = realIndex })

					if not onlyCheck then
						-- 非检测模式无需找到所有pattern，找到任意一个就返回
						-- 检测模式则遍历所有可能的结果，并统计
						return 
					end
				end
			end
		end
	end

	tryFind(selectMode)
	--usedLogMap

	if not lockDs then

		for i = 1 , modeCount do

			if #resultPosList > 0 then
				break
			end

			selectMode = selectMode - 1

			if selectMode < 1 then
				if _needLog then printx( 1 , "UBFBoardInitAdjustLogic  mode" .. tostring(selectMode + 1) .. " PASS !") end
				break
			end

			if _needLog then printx( 1 , "UBFBoardInitAdjustLogic  mode" .. tostring(selectMode + 1) .. " PASS !") end

			if not usedLogMap or not usedLogMap[selectMode] then
				tryFind(selectMode)
			end
		end

		if #resultPosList == 0 then
			selectMode = ds

			for i = 1 , modeCount do

				if #resultPosList > 0 then
					break
				end

				selectMode = selectMode + 1

				if selectMode > modeCount then
					if _needLog then printx( 1 , "UBFBoardInitAdjustLogic  mode" .. tostring(selectMode - 1) .. " PASS !") end
					break
				end

				if _needLog then printx( 1 , "UBFBoardInitAdjustLogic  mode" .. tostring(selectMode - 1) .. " PASS !") end

				if not usedLogMap or not usedLogMap[selectMode] then
					tryFind(selectMode)
				end
			end
		end
	end

	if not onlyCheck then
		if #resultPosList > 0 then
			resultData = resultPosList[ UBFRandom:calcValue( boardContext:nextSeed(seedKey) , 1 , #resultPosList ) ]
		end
	end
	
	return #resultPosList > 0 , resultData ,  resultPosList
end

function UBFBoardInitAdjustLogic:doChangeBoardByVirtualSeed(resultData)

    local boardContext = self.levelContext:getBoardContext(1)
    local availableColorList = boardContext:getUseColors()

    local r = resultData.centerR
	local c = resultData.centerC

	local configList = patternConfig["mode" .. tostring(resultData.typeIndex)]
	local config = configList[resultData.patternIndex]

	local resultPosList = {}

	-- local boardModel = self.mainLogic:getBoardModel()
	-- local itemMap = self.mainLogic:getItemMap()
	-- local boardMap = self.mainLogic:getBoardMap()

    local gridRaw = boardContext:getGridRawDataByPos(r, c)
	if gridRaw then

		-- local color = self.mainLogic:randomColor()
        
		local cIndex1 = UBFRandom:calcValue( boardContext:nextSeed(seedKey) , 1 , #availableColorList )
		local cIndex2 = nil

		if cIndex1 == #availableColorList then
			cIndex2 = UBFRandom:calcValue( boardContext:nextSeed(seedKey) , 1 , #availableColorList - 1 )
		else
			cIndex2 = UBFRandom:calcValue( boardContext:nextSeed(seedKey) , cIndex1 + 1 , #availableColorList )
		end

		local color1 =  availableColorList[cIndex1]
		local color2 =  availableColorList[cIndex2]

        
		local itemRaw = gridRaw.itemMaster
        if itemRaw then
            itemRaw.color = color1
        end
		if _needLog then printx( 1 , "UBFBoardInitAdjustLogic  doChangeBoardByVirtualSeed 111") end

		for k,v in ipairs(config) do

			local fixr = v.dr
			local fixc = v.dc

			local ra = r + fixr - 4
			local ca = c + fixc - 4

			if _needLog then printx( 1 , "UBFBoardInitAdjustLogic  doChangeBoardByVirtualSeed 222" , ra , ca) end
            local aroundGridRaw = boardContext:getGridRawDataByPos(ra, ca)

			if aroundGridRaw then
				local aroundItemRaw = aroundGridRaw.itemMaster
				if aroundItemRaw then
                    if v.ct == 1 then
                        aroundItemRaw.color = color1
                    else
                        aroundItemRaw.color = color2
                    end
                end
			end
		end
	end
end