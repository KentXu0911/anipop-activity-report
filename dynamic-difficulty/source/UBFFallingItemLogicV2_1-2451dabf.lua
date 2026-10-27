_G.UBF_NO_REQUIRE_LUA_FLAG()

UBFFallingItemLogicV2_1 = class2( "UBFFallingItemLogicV2_1" , UBFBaseLogic )

-- local testPosR = 4
-- local testPosC = 8
local log = nil
--
--
--
--


--这个视图也会用，计算公式见UBFVAFLPFalling.lua开头
-- local _fallingSpdMap = { 8, 4, 3, 3, 2 }
local _fallingSpdMap = UBFGameFallingSpdMap
local _fallingSpdSide = 7
local _fallingId = 0


function UBFFallingItemLogicV2_1:init( createData )
    self.contextManager = UBFContextManager:getInstance()
    self.gameBoardLogic = createData.gameBoardLogic
    UBFBaseLogic.init( self , createData  )
end

--判断上下相邻的两个格子之间，是否有阻挡   gridContextUp为上方，gridContextDown为下方
--为什么不自动判断？因为调用的地方知道上下，性能能省点就省点
--has_falling_block_between_two_vertical_grids
function UBFFallingItemLogicV2_1:hasFallingBlockBetweenTwoVerticalGrids(gridRawDataUp , gridRawDataDown )

	local upUsed = gridRawDataUp.isUsed
	local downUsed = gridRawDataDown.isUsed

	if upUsed then
		if self:hasBottomBorderFallingBlocker(gridRawDataUp) then return true end
		-- if self:hasTopBorderFallingBlocker( gridContextDown ) then return true end --新棋盘里，不需要检测另一个格子了
	else
		if downUsed then
			if self:hasTopBorderFallingBlocker(gridRawDataDown) then return true end 
		end
	end
	
	local upGravity = gridRawDataUp.gravity
	local downGravity = gridRawDataDown.gravity

	--todo move to opMap

	if upGravity == GravityDirection.kDown then
		if upUsed and downUsed and downGravity == GravityDirection.kUp then
			return true
		end
		if self:gridHasEnterPortal(gridRawDataUp) then return true end
	elseif upGravity == GravityDirection.kUp then
		if self:gridHasExitPortal(gridRawDataUp) then return true end
	end

	if downGravity == GravityDirection.kDown then
		if self:gridHasExitPortal(gridRawDataDown) then return true end
	elseif downGravity == GravityDirection.kUp then
		if self:gridHasEnterPortal(gridRawDataDown) then return true end
	end

	return false
end

--判断左右相邻的两个格子之间，是否有阻挡   r1，c1为左侧，r2，c2为右侧
--为什么不自动判断？因为调用的地方知道左右，性能能省点就省点
--has_falling_block_between_two_horizontal_grids
function UBFFallingItemLogicV2_1:hasFallingBlockBetweenTwoHorizontalGrids(gridRawDataLeft , gridRawDataRight )

	local leftUsed = gridRawDataLeft.isUsed
	local rightUsed = gridRawDataRight.isUsed

	if leftUsed then
		if self:hasRightBorderFallingBlocker( gridRawDataLeft ) then return true end
	else
		if rightUsed then
			if self:hasLeftBorderFallingBlocker( gridRawDataRight ) then return true end
		end
	end

	local leftGravity = gridRawDataLeft.gravity
	local rightGravity = gridRawDataRight.gravity

	if leftGravity == GravityDirection.kRight then 
		if leftUsed and rightUsed and rightGravity == GravityDirection.kLeft then
			return true
		end
		if self:gridHasEnterPortal( gridRawDataLeft ) then return true end
	elseif leftGravity == GravityDirection.kLeft then 
		if self:gridHasExitPortal( gridRawDataLeft ) then return true end
	end

	if rightGravity == GravityDirection.kRight then
		if self:gridHasExitPortal( gridRawDataRight ) then return true end
	elseif rightGravity == GravityDirection.kLeft then
		if self:gridHasEnterPortal( gridRawDataRight ) then return true end
	end

	return false
end

-- 判断上下斜向的两个格子之间，是否有类绳子阻挡   
-- gridContext1为顶部 
-- gridContext2为左下或者右下（由fx控制）
-- has_falling_block_between_two_oblique_vertical_grids fx 1 = left 2 = right
function UBFFallingItemLogicV2_1:hasFallingBlockBetweenTwoObliqueVerticalGrids( boardContext , gridRawData1 , gridRawData2 , fx)

	--return gridContext:hasBorderBlocker( UBFDirection.kDown )

	----[[
	-- if not mainLogic:isPosValid(r1, c1) then return false end
	-- if not mainLogic:isPosValid(r2, c2) then return false end

	-- local boardMap = mainLogic:getBoardMap()
	-- local board1 = boardMap[r1][c1] --顶点位置
	-- local board2 = boardMap[r2][c2] --底部位置

	local gravity1 = gridRawData1.gravity  --顶点位置
	local gravity2 = gridRawData2.gravity   --底部位置(相对顶点的左下或者右下，注意，这里的方向是根据重力方向的的相对方向)

	local r1 = gridRawData1.pos.r
	local c1 = gridRawData1.pos.c
	

	if gravity1 == GravityDirection.kDown then --todo move to opMapß

		-- local gridContext3 = boardContext:getGridContextByPos( r1 + 1, c1 ) --下方直角转角位置，用于判断类绳子阻断，UBF框架下已经无需判断

		if fx == 1 then
			--右上至左下(注意，这里的方向指的是相对方向，即重力为下时的方向)
			if gravity2 == GravityDirection.kUp or gravity2 == GravityDirection.kRight then
				return true
			end

			if self:hasRightBorderFallingBlocker( gridRawData2 ) --[[or ( gridContext3 and self:hasLeftBorderFallingBlocker( gridContext3 ) )]] then
				return true
			end
		else
			--左上至右下(注意，这里的方向指的是相对方向，即重力为下时的方向)
			if gravity2 == GravityDirection.kUp or gravity2 == GravityDirection.kLeft then
				return true
			end
			if self:hasLeftBorderFallingBlocker( gridRawData2 ) --[[or ( gridContext3 and self:hasRightBorderFallingBlocker( gridContext3 ) )]] then
				return true
			end
		end

		-- if gridContext3 then gridContext3:release() end

	elseif gravity1 == GravityDirection.kUp then

		-- local gridContext3 = boardContext:getGridContextByPos( r1 - 1, c1 )

		if fx == 1 then
			--右上至左下(注意，这里的方向指的是相对方向，即重力为下时的方向)
			if gravity2 == GravityDirection.kDown or gravity2 == GravityDirection.kLeft then
				return true
			end
			if self:hasLeftBorderFallingBlocker( gridRawData2 ) --[[or ( gridContext3 and self:hasRightBorderFallingBlocker( gridContext3 ) )]] then
				return true
			end
		else
			--左上至右下(注意，这里的方向指的是相对方向，即重力为下时的方向)
			if gravity2 == GravityDirection.kDown or gravity2 == GravityDirection.kRight then
				return true
			end
			if self:hasRightBorderFallingBlocker( gridRawData2 ) --[[or ( gridContext3 and self:hasLeftBorderFallingBlocker( gridContext3 ) )]] then
				return true
			end
		end
		
		-- if gridContext3 then gridContext3:release() end

	elseif gravity1 == GravityDirection.kLeft then

		-- local gridContext3 = boardContext:getGridContextByPos( r1, c1 - 1 )

		if fx == 1 then
			--右上至左下(注意，这里的方向指的是相对方向，即重力为下时的方向)
			if gravity2 == GravityDirection.kDown or gravity2 == GravityDirection.kRight then
				return true
			end
			if self:hasBottomBorderFallingBlocker( gridRawData2 ) --[[or ( gridContext3 and self:hasTopBorderFallingBlocker( gridContext3 ) )]] then
				return true
			end
		else
			--左上至右下(注意，这里的方向指的是相对方向，即重力为下时的方向)
			if gravity2 == GravityDirection.kUp or gravity2 == GravityDirection.kRight then
				return true
			end
			if self:hasTopBorderFallingBlocker( gridRawData2 ) --[[or ( gridContext3 and self:hasBottomBorderFallingBlocker( gridContext3 ) )]] then
				return true
			end
		end

		-- if gridContext3 then gridContext3:release() end

	else
		-- local gridContext3 = boardContext:getGridContextByPos( r1, c1 + 1 )

		if fx == 1 then
			--右上至左下(注意，这里的方向指的是相对方向，即重力为下时的方向)
			if gravity2 == GravityDirection.kUp or gravity2 == GravityDirection.kLeft then
				return true
			end
			if self:hasTopBorderFallingBlocker( gridRawData2 ) --[[or ( gridContext3 and self:hasBottomBorderFallingBlocker( gridContext3 ) )]] then
				return true
			end
		else
			--左上至右下(注意，这里的方向指的是相对方向，即重力为下时的方向)
			if gravity2 == GravityDirection.kDown or gravity2 == GravityDirection.kLeft then
				return true
			end
			if self:hasBottomBorderFallingBlocker( gridRawData2 ) --[[or ( gridContext3 and self:hasTopBorderFallingBlocker( gridContext3 ) )]] then
				return true
			end
		end

		-- if gridContext3 then gridContext3:release() end
	end
	--]]
	return false
end

--is_grid_can_be_falling_out
function UBFFallingItemLogicV2_1:isGridCanBeFallingOut(gridRawData) --有东西能掉出去
	if not gridRawData then 
		-- if _needtest then printx( 1 , "isGridCanBeFallingOut   FALSE 1" ) end
		return false 
	end

	local _needtest = false
	-- if gridContext._rawData.pos.r == testPosR and gridContext._rawData.pos.c == testPosC then
	-- 	-- _needtest = true

	-- 	-- printx( 1 , "isGridCanBeFallingOut   gridContext = " , gridContext )
	-- 	-- printx( 1 , "isGridCanBeFallingOut   \n" , table.tostring(gridContext._rawData) )
	-- 	printx( 1 , "isGridCanBeFallingOut   gridContext.isUsed = " , gridContext:getValue( "isUsed" ) , gridContext._rawData.pos.r , gridContext._rawData.pos.c )
	-- 	printx( 1 , "isGridCanBeFallingOut   gridContext.getBlockFalling = " , gridContext:getBlockFalling())

	-- end


	if gridRawData.isUsed
		and ( not (gridRawData.fallingState == GridFallingState.kFalling) ) 
		and ( not gridRawData.isBlockFalling ) 
	then
		-- if _needtest then 
		-- 	printx( 1 , "isGridCanBeFallingOut   gridContext.getItemMasterRawData = " , gridContext:getItemMasterRawData() )
		-- end
		
		local hasAnyCanFallingItem = false
		if gridRawData.hasMFFItems then
			hasAnyCanFallingItem = UBFGridContext:rawCall(gridRawData, "hasAnyCanFallingItem")
		else
			local _item = gridRawData.itemMaster
			hasAnyCanFallingItem = _item and _item.canFalling > 0 
		end

		if hasAnyCanFallingItem then
			-- if _needtest then printx( 1 , "isGridCanBeFallingOut   TRUE" , debug.traceback() ) end
			return true
		end
	end

	-- if _needtest then printx( 1 , "isGridCanBeFallingOut   FALSE 2" ) end
	return false
end

--is_grid_can_be_falling_in
function UBFFallingItemLogicV2_1:isGridCanBeFallingIn(gridRawData) --能掉进来东西

	local _needtest = false    

	if not gridRawData then return false end

	-- if gridContext._rawData.pos.r == 9 and gridContext._rawData.pos.c == 4 then
	-- 	_needtest = true
	-- 	printx( 1 , "isGridCanBeFallingIn   gridContext.isUsed = " , gridContext:getValue( "isUsed" ) , gridContext._rawData.pos.r , gridContext._rawData.pos.c , "getBlockFalling:" , gridContext:getBlockFalling() )
	-- end

	if gridRawData.isUsed 
		and ( not (gridRawData.fallingState == GridFallingState.kFalling) ) 
		and ( not gridRawData.isBlockFalling ) then

		-- if _needtest then 
		-- 	printx( 1 , "isGridCanBeFallingIn   gridContext.getItemMasterRawData = " , gridContext:getItemMasterRawData() )
		-- end

		if not gridRawData.itemMaster then
			return true
		end
	end
	return false
end

-- 格子下方是否存在 阻隔掉落的 边缘障碍（类绳子、冰柱、生效的风洞边缘等）,此类障碍会两格间发生掉落
function UBFFallingItemLogicV2_1:hasBottomBorderFallingBlocker( gridRawData )
	local borderBlockerMap = gridRawData.borderBlockerMap
	if borderBlockerMap[UBFDirection.kDown] ~= nil then return borderBlockerMap[UBFDirection.kDown].blockFalling end
	return UBFGridContext:rawCall(gridRawData, "hasBorderFallingBlocker", UBFDirection.kDown)
	-- return gridContext:hasBorderFallingBlocker( UBFDirection.kDown )
end

-- 格子上方是否存在 阻隔掉落的 边缘障碍（类绳子、冰柱、生效的风洞边缘等）,此类障碍会两格间发生掉落
function UBFFallingItemLogicV2_1:hasTopBorderFallingBlocker( gridRawData )
	local borderBlockerMap = gridRawData.borderBlockerMap
	if borderBlockerMap[UBFDirection.kUp] ~= nil then return borderBlockerMap[UBFDirection.kUp].blockFalling end
	return UBFGridContext:rawCall(gridRawData, "hasBorderFallingBlocker", UBFDirection.kUp)
	-- return gridContext:hasBorderFallingBlocker( UBFDirection.kUp )
end

-- 格子左方是否存在 阻隔掉落的 边缘障碍（类绳子、冰柱、生效的风洞边缘等）,此类障碍会两格间发生掉落
function UBFFallingItemLogicV2_1:hasLeftBorderFallingBlocker( gridRawData )
	local borderBlockerMap = gridRawData.borderBlockerMap
	if borderBlockerMap[UBFDirection.kLeft] ~= nil then return borderBlockerMap[UBFDirection.kLeft].blockFalling end
	return UBFGridContext:rawCall(gridRawData, "hasBorderFallingBlocker", UBFDirection.kLeft)
	-- return gridContext:hasBorderFallingBlocker( UBFDirection.kLeft )
end

-- 格子右方是否存在 阻隔掉落的 边缘障碍（类绳子、冰柱、生效的风洞边缘等）,此类障碍会两格间发生掉落
function UBFFallingItemLogicV2_1:hasRightBorderFallingBlocker( gridRawData )
	local borderBlockerMap = gridRawData.borderBlockerMap
	if borderBlockerMap[UBFDirection.kRight] ~= nil then return borderBlockerMap[UBFDirection.kRight].blockFalling end
	return UBFGridContext:rawCall(gridRawData, "hasBorderFallingBlocker", UBFDirection.kRight)
	-- return gridContext:hasBorderFallingBlocker( UBFDirection.kRight )
end

-- 格子上方是否存在 阻隔生成的 边缘障碍（类冰柱）,此类障碍会阻挡 传送门 和 生成口
function UBFFallingItemLogicV2_1:hasTopBorderProdBlocker(gridRawData)
	local borderBlockerMap = gridRawData.borderBlockerMap
	if borderBlockerMap[UBFDirection.kUp] ~= nil then return borderBlockerMap[UBFDirection.kUp].blockProd end
	return UBFGridContext:rawCall(gridRawData, "hasBorderProdBlocker", UBFDirection.kUp)
end

-- 格子下方是否存在 阻隔生成的 边缘障碍（类冰柱）,此类障碍会阻挡 传送门 和 生成口
function UBFFallingItemLogicV2_1:hasBottomBorderProdBlocker(gridRawData)
	local borderBlockerMap = gridRawData.borderBlockerMap
	if borderBlockerMap[UBFDirection.kDown] ~= nil then return borderBlockerMap[UBFDirection.kDown].blockProd end
	return UBFGridContext:rawCall(gridRawData, "hasBorderProdBlocker", UBFDirection.kDown)
end

-- 格子左方是否存在 阻隔生成的 边缘障碍（类冰柱）,此类障碍会阻挡 传送门 和 生成口
function UBFFallingItemLogicV2_1:hasLeftBorderProdBlocker(gridRawData)
	local borderBlockerMap = gridRawData.borderBlockerMap
	if borderBlockerMap[UBFDirection.kLeft] ~= nil then return borderBlockerMap[UBFDirection.kLeft].blockProd end
	return UBFGridContext:rawCall(gridRawData, "hasBorderProdBlocker", UBFDirection.kLeft)
end

-- 格子右方是否存在 阻隔生成的 边缘障碍（类冰柱）,此类障碍会阻挡 传送门 和 生成口
function UBFFallingItemLogicV2_1:hasRightBorderProdBlocker(gridRawData)
	local borderBlockerMap = gridRawData.borderBlockerMap
	if borderBlockerMap[UBFDirection.kRight] ~= nil then return borderBlockerMap[UBFDirection.kRight].blockProd end
	return UBFGridContext:rawCall(gridRawData, "hasBorderProdBlocker", UBFDirection.kRight)
end

-- 格子上方是否存在 阻隔交换的 边缘障碍（类绳子、冰柱）,此类障碍会两格间发生交换
function UBFFallingItemLogicV2_1:hasTopBorderSwapBlocker( gridRawData )
	local borderBlockerMap = gridRawData.borderBlockerMap
	if borderBlockerMap[UBFDirection.kUp] ~= nil then return borderBlockerMap[UBFDirection.kUp].blockSwap end
	return UBFGridContext:rawCall(gridRawData, "hasBorderSwapBlocker", UBFDirection.kUp)
	-- return gridContext:hasBorderSwapBlocker( UBFDirection.kUp ) 
end

-- 格子下方是否存在 阻隔交换的 边缘障碍（类绳子、冰柱）,此类障碍会两格间发生交换
function UBFFallingItemLogicV2_1:hasBottomBorderSwapBlocker( gridRawData )
	local borderBlockerMap = gridRawData.borderBlockerMap
	if borderBlockerMap[UBFDirection.kDown] ~= nil then return borderBlockerMap[UBFDirection.kDown].blockSwap end
	return UBFGridContext:rawCall(gridRawData, "hasBorderSwapBlocker", UBFDirection.kDown)
	-- return gridContext:hasBorderSwapBlocker( UBFDirection.kDown ) 
end

-- 格子左方是否存在 阻隔交换的 边缘障碍（类绳子、冰柱）,此类障碍会两格间发生交换
function UBFFallingItemLogicV2_1:hasLeftBorderSwapBlocker( gridRawData )
	local borderBlockerMap = gridRawData.borderBlockerMap
	if borderBlockerMap[UBFDirection.kLeft] ~= nil then return borderBlockerMap[UBFDirection.kLeft].blockSwap end
	return UBFGridContext:rawCall(gridRawData, "hasBorderSwapBlocker", UBFDirection.kLeft)
	-- return gridContext:hasBorderSwapBlocker( UBFDirection.kLeft )  
end

-- 格子右方是否存在 阻隔交换的 边缘障碍（类绳子、冰柱）,此类障碍会两格间发生交换
function UBFFallingItemLogicV2_1:hasRightBorderSwapBlocker( gridRawData )
	local borderBlockerMap = gridRawData.borderBlockerMap
	if borderBlockerMap[UBFDirection.kRight] ~= nil then return borderBlockerMap[UBFDirection.kRight].blockSwap end
	return UBFGridContext:rawCall(gridRawData, "hasBorderSwapBlocker", UBFDirection.kRight)
	-- return gridContext:hasBorderSwapBlocker( UBFDirection.kRight )  
end

function UBFFallingItemLogicV2_1:gridHasEnterPortal( gridRawData )
	return self:getGridEnterPortalRawData( gridRawData ) and true or false
end

function UBFFallingItemLogicV2_1:gridHasExitPortal( gridRawData )
	return self:getGridExitPortalRawData( gridRawData ) and true or false
end

function UBFFallingItemLogicV2_1:getGridEnterPortalRawData(gridRawData)
	local portals = gridRawData[UBFGridContext.itemTypeMapKey][UBFGameItemType.kPortal]
	if not portals then return end
	if portals[1] and portals[1].nextGridPos then return portals[1] end
	if portals[2] and portals[2].nextGridPos then return portals[2] end
end

function UBFFallingItemLogicV2_1:getGridExitPortalRawData(gridRawData)
	local portals = gridRawData[UBFGridContext.itemTypeMapKey][UBFGameItemType.kPortal]
	if not portals then return end
	if portals[1] and portals[1].prevGridPos then return portals[1] end
	if portals[2] and portals[2].prevGridPos then return portals[2] end
end

function UBFFallingItemLogicV2_1:gridHasProducer(gridRawData)
	local producers = gridRawData[UBFGridContext.itemTypeMapKey][UBFGameItemType.kProducer]
	local producer = producers and producers[1]
	if producer then 
		return true 
	else 
		return false 
	end
end




local _checkFallingByPortalOpMap1 = {
	[GravityDirection.kUp] = function ( selfObj , gridRawData ) 
		return selfObj:hasTopBorderProdBlocker( gridRawData )
	end ,
	[GravityDirection.kDown] = function ( selfObj , gridRawData ) 
		return selfObj:hasBottomBorderProdBlocker( gridRawData )
	end ,
	[GravityDirection.kLeft] = function ( selfObj , gridRawData ) 
		return selfObj:hasLeftBorderProdBlocker( gridRawData )
	end ,
	[GravityDirection.kRight] = function ( selfObj , gridRawData ) 
		return selfObj:hasRightBorderProdBlocker( gridRawData )
	end ,
}

local _checkFallingByPortalOpMap2 = {
	[GravityDirection.kUp] = function ( selfObj , gridContext ) 
		return selfObj:hasBottomBorderProdBlocker( gridContext )
	end ,
	[GravityDirection.kDown] = function ( selfObj , gridContext ) 
		return selfObj:hasTopBorderProdBlocker( gridContext )
	end ,
	[GravityDirection.kLeft] = function ( selfObj , gridContext ) 
		return selfObj:hasRightBorderProdBlocker( gridContext )
	end ,
	[GravityDirection.kRight] = function ( selfObj , gridContext ) 
		return selfObj:hasLeftBorderProdBlocker( gridContext )
	end ,
}

--check_falling_by_portal
function UBFFallingItemLogicV2_1:checkFallingByPortal(boardContext, gridRawData, r, c, vfPlan)

    -- local posKey =  r * MACRO_POS_STRIDE + c
    -- if vfPlan[posKey] then return false end --此格子当帧已经标记为无需计算

    local fallingState = gridRawData.fallingState
    if fallingState == GridFallingState.kFalling then
        return false --已经处于掉落中，不能再次穿过传送门
    end

	if not gridRawData.inBorder then return false end

	local portalRawData = self:getGridEnterPortalRawData(gridRawData) 
	if not portalRawData then return false end

	--本格子是否有东西能掉出去呢？
	if not self:isGridCanBeFallingOut(gridRawData) then return false end

	--todo 循环掉落判断？见NewFallingItemLogic ctx

	local enterGravity = gridRawData.gravity

	--判断入口是否被边缘障碍阻挡了传送
	if _checkFallingByPortalOpMap1[enterGravity](self, gridRawData) then
		return false
	end

	--出口
	local toGridPos = portalRawData.nextGridPos
	local toGridRawData = boardContext:getGridRawDataByPos(toGridPos.r, toGridPos.c)
	local exitGravity = toGridRawData.gravity

	--还不行呢
	if toGridRawData.fallingState == GridFallingState.kFalling then
		return false
	end

	--判断出口是否被某些奇怪的东西堵上
	if _checkFallingByPortalOpMap2[exitGravity](self, toGridRawData) then
		return false
	end

	--掉下去！
	local result = self:isGridCanBeFallingIn(toGridRawData)

	return result
end

--do_falling_by_portal
function UBFFallingItemLogicV2_1:doFallingByPortal( boardContext , r , c , viewActlist )

	local gridContext_start = boardContext:getGridContextByPos( r , c )
	local portalRawData = self:getGridEnterPortalRawData(gridContext_start._rawData) 
	local fromGridPos = gridContext_start:getValue( "pos" )
	local toGridPos = portalRawData.nextGridPos
	
	local fallingItems = gridContext_start:getFallingableItemRawDatas()
	gridContext_start:removeItemContextByList( fallingItems )

	local gridContext_end = boardContext:getGridContextByPos( toGridPos.r , toGridPos.c )
	gridContext_end:fallingIn( fromGridPos.r , fromGridPos.c , fallingItems )

	gridContext_start:setValue( "fallingState" , GridFallingState.kNormal )
	gridContext_end:setValue( "fallingState" , GridFallingState.kFalling )

	-- 印象里传送门速度会变为0
	-- local currFallingIndex = 0 
	local currFallingIndex = gridContext_start:getValue("fallingIndex") 

	local startFallingId = gridContext_start:getValue("fallingId") 
	if not startFallingId then
		startFallingId = self:getNewFallingId()
	end

	-- if maxFallingIndex and currFallingIndex > maxFallingIndex then currFallingIndex = maxFallingIndex end
	gridContext_end:setValue( "fallingIndex" , currFallingIndex ) --传送门通过后不能减速
	gridContext_start:setValue("fallingIndex" , 0)

	-- printx(21, startFallingId , currFallingIndex, fromGridPos.r , fromGridPos.c  )

    gridContext_start:setValue( "lastFallingType" , nil )
    gridContext_end:setValue("lastFallingType", UBFGameFallingType.kPortal)

	gridContext_start:setValue( "fallingId" , nil )
    gridContext_end:setValue("fallingId", startFallingId)

	local gridGravity = gridContext_start:getGravity()
	
	local fallingFrameRange = _fallingSpdMap[ currFallingIndex + 1 ] or _fallingSpdMap[#_fallingSpdMap]

	local currLogicFrameIndex = self.gameBoardLogic:getCurrLogicFrameIndex()
    local datas = {
		fallingId = startFallingId,
		fallingType = UBFGameFallingType.kPortal,
		fallingIndex = currFallingIndex ,
        r = fromGridPos.r , c = fromGridPos.c , tr = toGridPos.r , tc = toGridPos.c ,
		frames = fallingFrameRange ,
		dir = GravityDirectionToDirection[gridGravity],
		exitDir =  GravityDirectionToDirection[gridContext_end:getGravity()],
		boardId = boardContext:getValue("boardId"),
		fallingIds = UBFHelper:toList( fallingItems , function( v ) return v.id end ) ,
    }

	gridContext_start:release()
	gridContext_end:release()

	self:updateVerticalFallingPlan( boardContext , toGridPos.r , toGridPos.c , true )
	
    self.gameBoardLogic:createAndAddLogicAction(  UBFLogicActionType.kItemPortalToNextGrid , datas , currLogicFrameIndex + fallingFrameRange )
	
	local act = UBFViewActionData:create( 
											UBFViewActionType.kItemPortalToNextGrid , 
											datas, 
											currLogicFrameIndex,
											datas.boardId
										)
	table.insert( viewActlist , act )
end

-- 检查(r,c)位置的上一格，看看能否直线掉落至（r,c），如果能，就执行掉落
--check_and_falling_prev_grid
function UBFFallingItemLogicV2_1:_checkAndFallingPrevGrid( boardContext , r , c , viewActlist , backStop )

    local gridRawData = boardContext:getGridRawDataByPos(r, c)
    local gravity = gridRawData.gravity

    local prevGridRawData = nil
    local _hasPrev = false
    local _pos = nil

    if gravity == GravityDirection.kDown then
		local _prevInBorder = boardContext:isInBoardBorder(r - 1, c)
		if _prevInBorder then
			prevGridRawData = boardContext:getGridRawDataByPos(r - 1, c)
			if prevGridRawData and prevGridRawData.gravity == gravity then
				_hasPrev = true --上方格子合法
			else
				-- prevGridContext 不合法，它并不能掉落到 gridContext 位置
				-- 需要重新寻找 prevGridContext ，尝试另外两个方向（有传送门入口的方向不需要检测）
				prevGridRawData = boardContext:getGridRawDataByPos( r , c + 1 )
				if prevGridRawData and prevGridRawData.gravity == GravityDirection.kLeft then
					_hasPrev = true --右边格子合法
				else
					prevGridRawData = boardContext:getGridRawDataByPos( r , c - 1 )
					if prevGridRawData and prevGridRawData.gravity == GravityDirection.kRight then
						_hasPrev = true --左边格子合法
					end
				end
			end
		end
    elseif gravity == GravityDirection.kUp then

		local _prevInBorder = boardContext:isInBoardBorder( r + 1 , c )

		if _prevInBorder then
			prevGridRawData = boardContext:getGridRawDataByPos( r + 1 , c )
			if prevGridRawData and prevGridRawData.gravity == gravity then
				_hasPrev = true --下方格子合法
			else
				-- prevGridContext 不合法，它并不能掉落到 gridContext 位置
				-- 需要重新寻找 prevGridContext ，尝试另外两个方向（有传送门入口的方向不需要检测）
				prevGridRawData = boardContext:getGridRawDataByPos( r , c + 1 )
				if prevGridRawData and prevGridRawData.gravity == GravityDirection.kLeft then
					_hasPrev = true --右边格子合法
				else
					prevGridRawData = boardContext:getGridRawDataByPos( r , c - 1 )
					if prevGridRawData and prevGridRawData.gravity == GravityDirection.kRight then
						_hasPrev = true --左边格子合法
					end
				end
			end
		end    
    elseif gravity == GravityDirection.kLeft then

		local _prevInBorder = boardContext:isInBoardBorder( r , c + 1 )

		if _prevInBorder then
			prevGridRawData = boardContext:getGridRawDataByPos( r , c + 1 )
			if prevGridRawData and prevGridRawData.gravity == gravity then
				_hasPrev = true --右边格子合法
			else
				-- prevGridContext 不合法，它并不能掉落到 gridContext 位置
				-- 需要重新寻找 prevGridContext ，尝试另外两个方向（有传送门入口的方向不需要检测）
				prevGridRawData = boardContext:getGridRawDataByPos( r + 1 , c )
				if prevGridRawData and prevGridRawData.gravity == GravityDirection.kUp then
					_hasPrev = true --下方格子合法
				else
					prevGridRawData = boardContext:getGridRawDataByPos( r - 1 , c )
					if prevGridRawData and prevGridRawData.gravity == GravityDirection.kDown then
						_hasPrev = true --上方格子合法
					end
				end
			end
		end
    else

		local _prevInBorder = boardContext:isInBoardBorder( r , c - 1 )

		if _prevInBorder then
			prevGridRawData = boardContext:getGridRawDataByPos( r , c - 1 )
			if prevGridRawData and prevGridRawData.gravity == gravity then
				_hasPrev = true --左边格子合法
			else
				-- prevGridContext 不合法，它并不能掉落到 gridContext 位置
				-- 需要重新寻找 prevGridContext ，尝试另外两个方向（有传送门入口的方向不需要检测）
				prevGridRawData = boardContext:getGridRawDataByPos( r + 1 , c )
				if prevGridRawData and prevGridRawData.gravity == GravityDirection.kUp then
					_hasPrev = true --下方格子合法
				else
					prevGridRawData = boardContext:getGridRawDataByPos( r - 1 , c )
					if prevGridRawData and prevGridRawData.gravity == GravityDirection.kDown then
						_hasPrev = true --上方格子合法
					end
				end
			end
		end
    end

    --todo 如果需要结果绝对正确，需要将checkFallingByBottomEmpty的判断放到prevGridContext可用性判断里
    --即如果直线方向不能掉落，就要立刻判断90度方向的掉落

    -- printx( 1 , "_checkAndFallingPrevGrid  _hasPrev:" , _hasPrev, "  r:" , r , "c:" , c )
    if _hasPrev then
        -- 上一格存在
		_pos = prevGridRawData.pos
        local fallingState = prevGridRawData.fallingState
        -- printx( 1 , "_checkAndFallingPrevGrid  fallingState:" , fallingState )
        if fallingState ~= GridFallingState.kFalling then
            -- printx( 1 , "_checkAndFallingPrevGrid  _pos:" , _pos.r , _pos.c)
            if self:checkFallingByBottomEmpty( boardContext , prevGridRawData , _pos.r , _pos.c ) then
                -- printx( 1 , "_checkAndFallingPrevGrid doFallingByBottomEmpty  ---- " , _pos.r , _pos.c ) 
                if backStop then backStop(prevGridRawData) end
				self:doFallingByBottomEmpty( boardContext , _pos.r , _pos.c, viewActlist )
                return true , _pos
            end
        end
    else
        if prevGridRawData then
            _pos = prevGridRawData.pos
        end
    end

    return false , _pos
end

--do_recursion_vffalling
function UBFFallingItemLogicV2_1:doRecursionVFFalling( boardContext , r , c , viewActlist , needPortalCheckOnFirstGrid , backStop )
    -- r,c为一个空格子，
    -- 本方法将从（r,c）开始，沿重力方向的反方向递归寻找每一格，看看能否沿重力方向掉落，如果能掉落就执行掉落
    -- 如果重力方向的反方向不能掉落，那么会尝试从另外两个90度方向掉落
    -- needPortalCheckOnFirstGrid 的含义是，如果它为true，（r,c）位置的上一格如果不能掉落，就要检测（r,c）位置是否有传送门传送
    
    -- printx( 1 , "doRecursionVFFalling  _checkAndFallingPrevGrid  ---- " , r , c )

    local _checkResult , _prevPos = self:_checkAndFallingPrevGrid( boardContext , r , c , viewActlist, backStop )
    -- printx( 1 , "doRecursionVFFalling  _checkAndFallingPrevGrid  check result : " , _checkResult )

    if _checkResult then
        --开始递归

        _checkResult = false

        while(true) do 

            local _pr = _prevPos.r
            local _pc = _prevPos.c
            -- printx( 1 , "doRecursionVFFalling  While  _checkAndFallingPrevGrid  ---- " , _pr , _pc )
            _checkResult , _prevPos = self:_checkAndFallingPrevGrid( boardContext , _pr , _pc , viewActlist , backStop )

            if not _prevPos then
                -- printx( 1 , "doRecursionVFFalling  While  break 1 !!!"  )
                break --prev格子不存在，算法结束
            end

            -- printx( 1 , "doRecursionVFFalling  While  _checkAndFallingPrevGrid  check result :" , _checkResult , _pr , _pc )
            if not _checkResult then
                -- 二级递归
                -- prev格子存在，但无法直线掉落，继续检测prev格子上的传送门
                -- printx( 1 , "doRecursionVFFalling  While checkGridIsPortalExitAndJustEmpty ---- " , _pr , _pc )
                if not self:checkGridIsPortalExitAndJustEmpty( boardContext , _pr , _pc , viewActlist , backStop ) then
					local gridRawData = boardContext:getGridRawDataByPos( _pr , _pc )
					if gridRawData then
						local producers = gridRawData[UBFGridContext.itemTypeMapKey][UBFGameItemType.kProducer]
						local producer = producers and producers[1]
						-- printx( 1 , "doRecursionVFFalling  While producer ---- " , _pr , _pc )
						if producer then
							-- printx( 1 , "doRecursionVFFalling  While checkFallingByCannon " , _pr, _pc)
							if self:checkFallingByCannon( boardContext , _pr, _pc ) then 
								-- printx( 1 , "doRecursionVFFalling  While doFallingByCannon " , _pr, _pc)
								self:doFallingByCannon( boardContext , _pr , _pc , viewActlist )
							end
						end
					end
				end
                -- printx( 1 , "doRecursionVFFalling  While  break 2 !!!"  )
                break
            end
        end

		return true
    else
        if needPortalCheckOnFirstGrid then
            self:checkGridIsPortalExitAndJustEmpty( boardContext , r , c , viewActlist , backStop )
        end

		return false
    end
end

local _targetGridCanDropInOpMap = {
	[GravityDirection.kUp] = function (_self, boardContext, r, c, gridRawData) 
		if not _self:isInBoardBoarder(boardContext, r - 1, c) then 
			-- if log then log("_targetGridCanDropInOpMap GravityDirection.kUp ---- return 1  false", r, c) end
			return false 
		end
		local gridRawData2 = boardContext:getGridRawDataByPos(r - 1, c)
		if not gridRawData2 then 
			-- if log then log("_targetGridCanDropInOpMap GravityDirection.kUp ---- return 2  false", r, c) end
			return false 
		end
		local _b =  _self:isGridCanBeFallingIn(gridRawData2) and not _self:hasFallingBlockBetweenTwoVerticalGrids(gridRawData2, gridRawData)
		-- if log then log("isGridCanBeFallingIn :", _self:isGridCanBeFallingIn( gridContext2 )) end
		-- if log then log("hasFallingBlockBetweenTwoVerticalGrids :", _self:hasFallingBlockBetweenTwoVerticalGrids( gridContext2 , gridContext )) end
		-- if log then log("_b :", _b) end
		return _b
	end,

	[GravityDirection.kDown] = function (_self , boardContext , r , c , gridRawData ) 
		if not _self:isInBoardBoarder( boardContext , r + 1 , c ) then return false end
		-- local _needtest = false
		-- if r == testPosR and c == testPosC then
		-- 	_needtest = true
		-- end
		local gridRawData2 = boardContext:getGridRawDataByPos( r + 1 , c )
		-- if _needtest then printx( 1 ,"_targetGridCanDropInOpMap  === 1" , r , c , " >> " ,  r + 1 , c  ) end
		if not gridRawData2 then 
			-- if _needtest then printx( 1 ,"_targetGridCanDropInOpMap  === 2"  ) end
			return false 
		end
		-- if _needtest then 
		-- 	printx( 1 ,"_targetGridCanDropInOpMap  === 3"  , _self:isGridCanBeFallingIn( gridContext2 ) ,  not _self:hasFallingBlockBetweenTwoVerticalGrids( gridContext , gridContext2 ) ) 

		-- 	printx( 1 , "gridContext2 = " , table.tostring(gridContext2:getRawData()) )
		
		-- end
		local _b =  _self:isGridCanBeFallingIn(gridRawData2) and not _self:hasFallingBlockBetweenTwoVerticalGrids(gridRawData, gridRawData2)
		return _b
	end,

	[GravityDirection.kLeft] = function (_self , boardContext , r , c , gridRawData ) 
		if not _self:isInBoardBoarder( boardContext , r , c - 1 ) then return false end
		local gridRawData2 = boardContext:getGridRawDataByPos( r , c - 1 )
		if not gridRawData2 then return false end
		local _b = _self:isGridCanBeFallingIn(gridRawData2) and not _self:hasFallingBlockBetweenTwoHorizontalGrids(gridRawData2, gridRawData)
		return _b
	end,

	[GravityDirection.kRight] = function (_self , boardContext , r , c , gridRawData ) 
		if not _self:isInBoardBoarder( boardContext , r , c + 1 ) then return false end
		local gridRawData2 = boardContext:getGridRawDataByPos( r , c + 1 )
		if not gridRawData2 then return false end
		local _b = _self:isGridCanBeFallingIn(gridRawData2) and not _self:hasFallingBlockBetweenTwoHorizontalGrids(gridRawData, gridRawData2)
		return _b
	end,
}

function UBFFallingItemLogicV2_1:isInBoardBoarder(boardContext, r , c)
	return boardContext:isInBoardBorder( r , c )
end

--check_falling_by_bottom_empty
function UBFFallingItemLogicV2_1:checkFallingByBottomEmpty(boardContext, gridRawData, r, c)
	
	local needPrint = false
	-- if r == 9 and c == 2 then
	-- 	needPrint = true
	-- end
	-- printx( 1 , "UBFFallingItemLogicV2_1:checkFallingByBottomEmpty  r" , r , "c" , c )

	-- local gridContext = boardContext:getGridContextByPos( r , c )

    if not self:isGridCanBeFallingOut(gridRawData) then
		-- if needPrint then printx( 1, "checkFallingByBottomEmpty  isGridCanBeFallingOut = false ------ return") end
        return false
    end

	local _canDropIn = _targetGridCanDropInOpMap[gridRawData.gravity](self, boardContext, r, c, gridRawData)

	-- gridContext:release()
	if needPrint then printx( 1, "checkFallingByBottomEmpty  _canDropIn:" , _canDropIn ) end 
	if _canDropIn then 	----正下方的格子可以被掉落进去
		
		return true
	end

	return false
end

local _doFallingByBottomEmptyOpMap = {
	[GravityDirection.kUp] = function ( _r , _c ) 
		return _r - 1 , _c		----上面空位
	end ,
	[GravityDirection.kDown] = function ( _r , _c ) 
		return _r + 1 , _c		----下面空位
	end ,
	[GravityDirection.kLeft] = function ( _r , _c )
		return _r , _c - 1		----左面空位
	end ,
	[GravityDirection.kRight] = function ( _r , _c ) 
		return _r , _c + 1 		----右面空位
	end ,
	[0] = function (  _r , _c )
		printx( 1 , "Get Gravity Error At :" , _r , _c , debug.traceback() )
	end,
}
function UBFFallingItemLogicV2_1:getNewFallingId()
	-- _fallingId = _fallingId + 1
	-- return _fallingId
	return self.gameBoardLogic.levelContext:genNextId()
end

--do_falling_by_bottom_empty
function UBFFallingItemLogicV2_1:doFallingByBottomEmpty( boardContext , r , c , viewActlist )

	local gridContext_start = boardContext:getGridContextByPos( r , c )

	local fallingItems = gridContext_start:getFallingableItemRawDatas()
	gridContext_start:removeItemContextByList( fallingItems )

	local tr , tc = _doFallingByBottomEmptyOpMap[gridContext_start:getGravity()]( r , c )
	
	local gridContext_end = boardContext:getGridContextByPos( tr , tc )
	gridContext_end:fallingIn( r , c , fallingItems )

	local maxFallingIndex --gridContext_end的下一格的速度

	--减速安全，防止追尾
	local portalRawData = self:getGridEnterPortalRawData( gridContext_end._rawData )
	local mr , mc
	if portalRawData then
		local _nextGridPos = portalRawData.nextGridPos 
		mr , mc = _nextGridPos.r , _nextGridPos.c
	else
		local gVec = _G.GravityDirectionVecMap[gridContext_end:getGravity()]
		mr , mc = tr + gVec.r , tc + gVec.c
	end

	local gridContext_more = boardContext:getGridContextByPos( mr , mc )
	if gridContext_more then 
		local fallingState = gridContext_more:getValue( "fallingState" )
		if fallingState ~= GridFallingState.kNormal then
			maxFallingIndex = gridContext_more:getValue("fallingIndex") 
		end
		gridContext_more:release()
	end

	gridContext_start:setValue( "fallingState" , GridFallingState.kNormal )
	gridContext_end:setValue( "fallingState" , GridFallingState.kFalling )

	
	local currFallingIndex = gridContext_start:getValue("fallingIndex") 
	local startFallingId = gridContext_start:getValue("fallingId") 

	-- if gridContext_start:getValue("lastFallingType") == UBFGameFallingType.kSide then
	-- 	currFallingIndex = 0
	-- end
	local fallingChangeId = nil

	if maxFallingIndex and currFallingIndex > maxFallingIndex then 
		currFallingIndex = maxFallingIndex 
		if startFallingId then fallingChangeId = startFallingId end
		startFallingId = self:getNewFallingId()
	end

	if not startFallingId then startFallingId = self:getNewFallingId() end

	gridContext_end:setValue("fallingIndex" , currFallingIndex)
	gridContext_start:setValue("fallingIndex" , 0)

    gridContext_start:setValue("lastFallingType", nil)
    gridContext_end:setValue("lastFallingType", UBFGameFallingType.kStraight)

	gridContext_start:setValue( "fallingId" , nil )
    gridContext_end:setValue("fallingId", startFallingId)
	
	local fallingFrameRange = _fallingSpdMap[ currFallingIndex + 1 ] or _fallingSpdMap[#_fallingSpdMap]
	

	local currLogicFrameIndex = self.gameBoardLogic:getCurrLogicFrameIndex()
    local datas = {
		fallingId = startFallingId,
		fallingType = UBFGameFallingType.kStraight,
		fallingIndex = currFallingIndex ,
		fallingChangeId = fallingChangeId,
        r = r , c = c , tr = tr , tc = tc ,
		gravity = gridContext_start:getGravity(),
		frames = fallingFrameRange ,
		boardId = boardContext:getValue("boardId"),
		fallingIds = UBFHelper:toList(fallingItems, function( v ) return v.id end),
    }

	gridContext_start:release()
	gridContext_end:release()
	
    self.gameBoardLogic:createAndAddLogicAction(  UBFLogicActionType.kItemFallingToNextGrid , datas , currLogicFrameIndex + fallingFrameRange )
	
	-- printx( 1 , "doFallingByBottomEmpty  " , r , c , " >>> " , tr , tc , "  Start Falling , currLogicFrameIndex:" , currLogicFrameIndex , "need " ,fallingFrameRange , " frames" , " falling done at "  ,currLogicFrameIndex + fallingFrameRange )

	if viewActlist then
		local act = UBFViewActionData:create( 
											UBFViewActionType.kItemFallingToNextGrid , 
											datas , 
											currLogicFrameIndex,
											datas.boardId
										)

		table.insert( viewActlist , act )
	end
	
end

-- function UBFFallingItemLogicV2_1:doFallingStop( boardContext , r , c)
-- 	local gridContext = boardContext:getGridContextByPos( r , c )
-- 	-- 抵达下一格，且无法继续掉落，切换为微稳定状态，并检测匹配三消
-- 	if false then 
-- 		printx( 1 , "直线掉落 ----- kJustArrive --> kHalfStable   gridRawData =" , gridRawData ) 
-- 	end
-- 	gridContext:setValue( "fallingState" , GridFallingState.kHalfStable  )
-- 	gridContext:release()
-- end

function UBFFallingItemLogicV2_1:doStopActions( boardContext , stopMap , viewActlist )
	for _ , data in pairs(stopMap) do
		local r , c = data.r , data.c
		local gridRawData = boardContext:getGridRawDataByPos(r, c)
		local fallingItems = UBFGridContext:rawCall(gridRawData, "getFallingableItemRawDatas")
		local currLogicFrameIndex = self.gameBoardLogic:getCurrLogicFrameIndex()
		local datas = {
			r = r , c = c ,
			fallingId = data.fallingId,
			fallingType = UBFGameFallingType.kStop,
			mayContinue = data.mayContinue,
			boardId = boardContext:getValue("boardId"),
			gravity = gridRawData.gravity,
			fallingIds = data.fallingIds or UBFHelper:toList(fallingItems, function( v ) return v.id end) ,
		}

		local act = UBFViewActionData:create( 
												UBFViewActionType.kItemFallingEnd, 
												datas, 
												currLogicFrameIndex,
												datas.boardId
											)
		table.insert(viewActlist, act)
	end
end

local __checkByPortalOpMap = {
	[GravityDirection.kUp] = function ( selfObj , gridRawData ) 
		if selfObj:hasTopBorderProdBlocker( gridRawData ) then
			-- 传送门被封死，当前格已经是掉落链的最远端格子，终止递归，递归起点可生成
			return true
		elseif selfObj:gridHasProducer( gridRawData ) then
			-- 如果存在生成口，
			-- 则生成口能启用就代表递归起点的格子需要禁用（返回false）
			-- 生成口不能启用就代表递归起点的格子可以生成（返回true）
			if selfObj:hasBottomBorderProdBlocker( gridRawData ) then
				return true
			else
				return false
			end
		end

		return 0 --需要继续递归
	end,
	[GravityDirection.kDown] = function ( selfObj , gridRawData ) 
		if selfObj:hasBottomBorderProdBlocker( gridRawData ) then
			-- 传送门被封死，当前格已经是掉落链的最远端格子，终止递归，递归起点可生成
			return true
		elseif selfObj:gridHasProducer( gridRawData ) then
			-- 如果存在生成口，
			-- 则生成口能启用就代表递归起点的格子需要禁用（返回false）
			-- 生成口不能启用就代表递归起点的格子可以生成（返回true）
			if selfObj:hasTopBorderProdBlocker( gridRawData ) then
				return true
			else
				return false
			end
			
		end

		return 0 --需要继续递归
	end,
	[GravityDirection.kLeft] = function ( selfObj , gridRawData ) 
		if selfObj:hasLeftBorderProdBlocker( gridRawData ) then
			-- 传送门被封死，当前格已经是掉落链的最远端格子，终止递归，递归起点可生成
			return true	
		elseif selfObj:gridHasProducer( gridRawData ) then
			-- 如果存在生成口，
			-- 则生成口能启用就代表递归起点的格子需要禁用（返回false）
			-- 生成口不能启用就代表递归起点的格子可以生成（返回true）
			if selfObj:hasRightBorderProdBlocker( gridRawData ) then
				return true
			else
				return false
			end
		end

		return 0 --需要继续递归
	end,
	[GravityDirection.kRight] = function ( selfObj , gridRawData ) 
		if selfObj:hasRightBorderProdBlocker( gridRawData ) then
			-- 传送门被封死，当前格已经是掉落链的最远端格子，终止递归，递归起点可生成
			return true
		elseif selfObj:gridHasProducer( gridRawData ) then
			-- 如果存在生成口，
			-- 则生成口能启用就代表递归起点的格子需要禁用（返回false）
			-- 生成口不能启用就代表递归起点的格子可以生成（返回true）
			if selfObj:hasLeftBorderProdBlocker( gridRawData ) then
				return true
			else
				return false
			end
		end

		return 0 --需要继续递归
	end,
}

local __checkByPortal = function( selfObj , enterR , enterC , boardContext , checkFunction , temGridObj )

	-- if textPrint then printx( 1 , "checkByPortal enterR:"  , enterR , "enterC:" , enterC   ) end
	local gridRawData = boardContext:getGridRawDataByPos( enterR , enterC )
	
	if not gridRawData.isMasterCanFalling then
		return true
	end

	local _result = __checkByPortalOpMap[gridRawData.gravity]( selfObj , gridRawData )

	if _result ~= 0 then
		-- printx( 1 , "__checkByPortal _result =" , _result , "  checkFunction enterR  enterC =" , enterR , enterC   )
		return _result
	else
		temGridObj.gravity = nil
		-- printx( 1 , "__checkByPortal temGridObj.gravity = nil !!!!  checkFunction enterR  enterC =" ,  enterR , enterC   )
		return checkFunction( enterR , enterC , false , true )
	end
	
end

local __checkFallingByCannonOpMap = {

	-- isFirstGrid = true
	[1] = {
		[GravityDirection.kUp] = function ( selfObj , boardContext , r , c , gridRawData , checkFunction , temGridObj , isPortalEnterMode ) 
			if selfObj:hasBottomBorderProdBlocker( gridRawData ) then
				--isFirstGrid意味着这个格子就是检测链最开始的那个生成口，而生成口被冰柱拦住一律不生成
				return false
			else
				local portalRawData = selfObj:getGridExitPortalRawData( gridRawData )
				if portalRawData then --绳子不挡传送门，所以先判断传送门，如果传送门不堵，就无视绳子，顺着传送门的入口格子继续遍历
					return __checkByPortal( selfObj , portalRawData.prevGridPos.r , portalRawData.prevGridPos.c , boardContext , checkFunction , temGridObj )
				elseif selfObj:hasBottomBorderFallingBlocker( gridRawData ) then
					return true --如果重力方向前方有绳子，则递归结束，允许生成
				end
			end

			return 0 , r + 1 , c
		end ,
		[GravityDirection.kDown] = function ( selfObj , boardContext , r , c , gridRawData , checkFunction , temGridObj , isPortalEnterMode ) 
			if selfObj:hasTopBorderProdBlocker( gridRawData ) then
				--isFirstGrid意味着这个格子就是检测链最开始的那个生成口，而生成口被冰柱拦住一律不生成
				return false
			else
				local portalRawData = selfObj:getGridExitPortalRawData( gridRawData )
				if portalRawData  then
					return __checkByPortal( selfObj , portalRawData.prevGridPos.r , portalRawData.prevGridPos.c , boardContext , checkFunction , temGridObj )
				elseif selfObj:hasTopBorderFallingBlocker( gridRawData ) then
					return true
				end
			end
			return 0 , r - 1 , c
		end ,
		[GravityDirection.kLeft] = function ( selfObj , boardContext , r , c , gridRawData , checkFunction , temGridObj , isPortalEnterMode ) 
			if selfObj:hasRightBorderProdBlocker( gridRawData ) then
				--isFirstGrid意味着这个格子就是检测链最开始的那个生成口，而生成口被冰柱拦住一律不生成
				return false
			else
				local portalRawData = selfObj:getGridExitPortalRawData( gridRawData )
				if portalRawData  then
					return __checkByPortal( selfObj , portalRawData.prevGridPos.r , portalRawData.prevGridPos.c , boardContext , checkFunction , temGridObj )
				elseif selfObj:hasRightBorderFallingBlocker( gridRawData ) then
					return true
				end
			end
			return 0 , r , c + 1
		end ,
		[GravityDirection.kRight] = function ( selfObj , boardContext , r , c , gridRawData , checkFunction , temGridObj , isPortalEnterMode ) 
			if selfObj:hasLeftBorderProdBlocker( gridRawData ) then
				--isFirstGrid意味着这个格子就是检测链最开始的那个生成口，而生成口被冰柱拦住一律不生成
				return false
			else
				local portalRawData = selfObj:getGridExitPortalRawData( gridRawData )
				if portalRawData  then
					return __checkByPortal( selfObj , portalRawData.prevGridPos.r , portalRawData.prevGridPos.c , boardContext , checkFunction , temGridObj )
				elseif selfObj:hasLeftBorderFallingBlocker( gridRawData ) then
					return true
				end
			end
			return 0 , r , c - 1
		end ,
	} ,

	-- isFirstGrid = false
	[2] = {
		[GravityDirection.kUp] = function ( selfObj , boardContext , r , c , gridRawData , checkFunction , temGridObj , isPortalEnterMode ) 
			if not isPortalEnterMode then
				--如果格子本身是block
				if not gridRawData.isMasterCanFalling and not (gridRawData.passProductCloseCheck > 0) then 
					return true
				end

				--格子底部有绳子、冰柱，或传送门入口，意味着此格子无法掉落至递归循环的上一格，所以递归初始格子的生成口允许掉落
				if selfObj:hasTopBorderFallingBlocker( gridRawData ) or selfObj:gridHasEnterPortal( gridRawData ) then 
					return true
				end
			end

			--格子顶部没有边缘生成阻挡（没有类冰柱障碍），即生成口和传送门出口是有效的
			if not selfObj:hasBottomBorderProdBlocker( gridRawData ) then 
				--有生成口，且没有被冰柱阻挡
				if selfObj:gridHasProducer( gridRawData ) then 
					return false
				end

				--有传送门出口，且没有被冰柱阻挡
				local portalRawData = selfObj:getGridExitPortalRawData( gridRawData )
				if portalRawData then 
					return __checkByPortal( selfObj , portalRawData.prevGridPos.r , portalRawData.prevGridPos.c , boardContext , checkFunction , temGridObj )
				end
			end

			if selfObj:hasBottomBorderFallingBlocker( gridRawData ) then --顶部有绳子
				return true
			end
			return 0 , r + 1 , c
		end ,
		[GravityDirection.kDown] = function ( selfObj , boardContext , r , c , gridRawData , checkFunction , temGridObj , isPortalEnterMode ) 
			if not isPortalEnterMode then
				--如果格子本身是block
				if not gridRawData.isMasterCanFalling and not (gridRawData.passProductCloseCheck > 0) then 
					-- printx( 1 , "__checkFallingByCannonOpMap[2]Down return1 true" )
					return true
				end

				--格子底部有绳子、冰柱，或传送门入口，意味着此格子无法掉落至递归循环的上一格，所以递归初始格子的生成口允许掉落
				if selfObj:hasBottomBorderFallingBlocker( gridRawData ) or selfObj:gridHasEnterPortal( gridRawData ) then 
					-- printx( 1 , "__checkFallingByCannonOpMap[2]Down selfObj:hasBottomBorderFallingBlocker( gridContext ) =" , selfObj:hasBottomBorderFallingBlocker( gridContext ) )
					-- printx( 1 , "__checkFallingByCannonOpMap[2]Down selfObj:gridHasEnterPortal( gridContext ) =" , selfObj:gridHasEnterPortal( gridContext ) )
					-- printx( 1 , "__checkFallingByCannonOpMap[2]Down return2 true" )
					return true
				end
			end

			--格子顶部没有边缘生成阻挡（没有类冰柱障碍），即生成口和传送门出口是有效的
			if not selfObj:hasTopBorderProdBlocker( gridRawData ) then 
				--有生成口，且没有被冰柱阻挡
				if selfObj:gridHasProducer( gridRawData ) then 
					-- printx( 1 , "__checkFallingByCannonOpMap[2]Down return3 false" )
					return false
				end
				-- printx( 1 , "__checkFallingByCannonOpMap[2]Down   temGridObj =" , temGridObj )
				--有传送门出口，且没有被冰柱阻挡
				local portalRawData = selfObj:getGridExitPortalRawData( gridRawData )
				if portalRawData then 
					-- printx( 1 , "__checkFallingByCannonOpMap[2]Down return4 ?" )
					return __checkByPortal( selfObj , portalRawData.prevGridPos.r , portalRawData.prevGridPos.c , boardContext , checkFunction , temGridObj )
				end
			end

			if selfObj:hasTopBorderFallingBlocker( gridRawData ) then --顶部有绳子
				-- printx( 1 , "__checkFallingByCannonOpMap[2]Down return5 true" )
				return true
			end

			-- printx( 1 , "__checkFallingByCannonOpMap[2]Down return6 CCC" )
			return 0 , r - 1 , c --继续遍历前一格
		end ,
		[GravityDirection.kLeft] = function ( selfObj , boardContext , r , c , gridRawData , checkFunction , temGridObj , isPortalEnterMode ) 
			if not isPortalEnterMode then
				--如果格子本身是block
				if not gridRawData.isMasterCanFalling and not (gridRawData.passProductCloseCheck > 0) then 
					return true
				end

				--格子底部有绳子、冰柱，或传送门入口，意味着此格子无法掉落至递归循环的上一格，所以递归初始格子的生成口允许掉落
				if selfObj:hasLeftBorderFallingBlocker( gridRawData ) or selfObj:gridHasEnterPortal( gridRawData ) then 
					return true
				end
			end

			--格子顶部没有边缘生成阻挡（没有类冰柱障碍），即生成口和传送门出口是有效的
			if not selfObj:hasRightBorderProdBlocker( gridRawData ) then 
				--有生成口，且没有被冰柱阻挡
				if selfObj:gridHasProducer( gridRawData ) then 
					return false
				end

				--有传送门出口，且没有被冰柱阻挡
				local portalRawData = selfObj:getGridExitPortalRawData( gridRawData )
				if portalRawData then 
					return __checkByPortal( selfObj , portalRawData.prevGridPos.r , portalRawData.prevGridPos.c , boardContext , checkFunction , temGridObj )
				end
			end

			if selfObj:hasRightBorderFallingBlocker( gridRawData ) then --顶部有绳子
				return true
			end
			return 0 , r , c + 1
		end ,
		[GravityDirection.kRight] = function ( selfObj , boardContext , r , c , gridRawData , checkFunction , temGridObj , isPortalEnterMode ) 
			if not isPortalEnterMode then
				--如果格子本身是block
				if not gridRawData.isMasterCanFalling and not (gridRawData.passProductCloseCheck > 0) then 
					return true
				end

				--格子底部有绳子、冰柱，或传送门入口，意味着此格子无法掉落至递归循环的上一格，所以递归初始格子的生成口允许掉落
				if selfObj:hasRightBorderFallingBlocker( gridRawData ) or selfObj:gridHasEnterPortal( gridRawData ) then 
					return true
				end
			end

			--格子顶部没有边缘生成阻挡（没有类冰柱障碍），即生成口和传送门出口是有效的
			if not selfObj:hasLeftBorderProdBlocker( gridRawData ) then 
				--有生成口，且没有被冰柱阻挡
				if selfObj:gridHasProducer( gridRawData ) then 
					return false
				end

				--有传送门出口，且没有被冰柱阻挡
				local portalRawData = selfObj:getGridExitPortalRawData( gridRawData )
				if portalRawData then 
					return __checkByPortal( selfObj , portalRawData.prevGridPos.r , portalRawData.prevGridPos.c , boardContext , checkFunction , temGridObj )
				end
			end

			if selfObj:hasLeftBorderFallingBlocker( gridRawData ) then --顶部有绳子
				return true
			end
			return 0 , r , c - 1
		end ,
	} ,
}

--check_falling_by_cannon
function UBFFallingItemLogicV2_1:checkFallingByCannon( boardContext , r , c )

	local boardBorder = boardContext:getBoardBorder( true )
	local gridRawData = boardContext:getGridRawDataByPos( r , c )

	-- printx( 1 , "checkFallingByCannon " , r , c  )
	
	if not self:isGridCanBeFallingIn(gridRawData) then 
		return false 
	end

	if gridRawData.fallingState == GridFallingState.kFalling then 
		return false 
	end

	-- do return true end --目前直接返回

	local temGridObj = {}
	-- local temGridObj.gravity = nil

	local function checkHasOtherCannon( _r , _c , isFirstGrid , isPortalEnterMode )
		-- printx( 1 , "checkFallingByCannon  ------------" , _r , _c , isFirstGrid , isPortalEnterMode )
		
		local _gridRawData = boardContext:getGridRawDataByPos( _r , _c )
		local _gridGravity = _gridRawData.gravity

		-- local item = itemMap[_r][_c] 
		-- local board = boardMap[_r][_c] 
		local _result , prevR , prevC = nil,nil,nil

		if isFirstGrid then

			temGridObj.gravity = _gridGravity

			
			_result , prevR , prevC = __checkFallingByCannonOpMap[1][temGridObj.gravity]( 
											self , boardContext , _r , _c , _gridRawData , checkHasOtherCannon , temGridObj , isPortalEnterMode )
			-- printx( 1 , "checkFallingByCannon isFirstGrid=true _result =" , _result , " prevR , prevC =" ,  prevR , prevC )

			if _result ~= 0 then
				-- printx( 1 , "checkFallingByCannon return 3 " , _result , _r , _c )
				return _result
			end
			-- printx( 1 , "checkFallingByCannon CCC 1 " , prevR , prevC )
		else

			if not temGridObj.gravity then
				temGridObj.gravity = _gridGravity
			end

			-- printx( 1 , "checkFallingByCannon temGridObj.gravity =" , temGridObj.gravity , "_gridGravity =" , _gridGravity )

			if temGridObj.gravity ~= _gridGravity then
				--重力方向不同，相当于中断递归，当前生成口（r , c）允许生成
				-- printx( 1 , "checkFallingByCannon return 4 " , true , _r , _c )
				return true
			end
			
			
			_result , prevR , prevC = __checkFallingByCannonOpMap[2][temGridObj.gravity]( 
											self , boardContext , _r , _c , _gridRawData , checkHasOtherCannon , temGridObj , isPortalEnterMode )
			-- printx( 1 , "checkFallingByCannon isFirstGrid=false  _result =" , _result , " prevR , prevC =" ,  prevR , prevC )

			if _result ~= 0 then
				-- printx( 1 , "checkFallingByCannon return 5 " , _result , _r , _c )
				return _result
			end
			-- printx( 1 , "checkFallingByCannon CCC 2 " , prevR , prevC )
		end

		if prevR < boardBorder.top or prevR > boardBorder.bottom or prevC < boardBorder.left or prevC > boardBorder.right then
			--递归到边界外，退出，当前生成口（r , c）允许生成
			-- printx( 1 , "checkFallingByCannon return 6 " , true , _r , _c )
			return true 
		else

		end

		return checkHasOtherCannon( prevR , prevC , false , false )
	end	

	return checkHasOtherCannon( r , c , true , false)
end

local _getFallingByCannonSpdOPMap = {
	[_G.GravityDirection.kUp] = function ( r , c ) 
		return r - 1 , c + 1 , r - 1 , c - 1
	end,
    [_G.GravityDirection.kDown] = function ( r , c ) 
		return r + 1 , c + 1 , r + 1 , c - 1
	end,
    [_G.GravityDirection.kLeft] = function ( r , c ) 
		return r + 1 , c - 1 , r - 1 , c - 1
	end,
    [_G.GravityDirection.kRight] = function ( r , c ) 
		return r + 1 , c + 1 , r - 1 , c + 1
	end,
}

local function setBlock(self) self.isBlock = true end

--do_falling_by_cannon
function UBFFallingItemLogicV2_1:doFallingByCannon(boardContext, r, c, viewActlist)

	local gridPos = { r = r , c = c }

	local gameBoardLogic = self.gameBoardLogic
	local prData = gameBoardLogic:callById(gameBoardLogic.productItemLogicId, "checkAndGetRule", boardContext, gridPos)
	if not prData then return false end

	local generator = gameBoardLogic:callById(gameBoardLogic.productItemLogicId, "doProduceByRuleData", boardContext, prData)
	if not generator then return false end

	local itemList = generator(gameBoardLogic, true)

	if not itemList then return false end

	if not prData.forbiddenFalsify then
		local importantSiteMap = gameBoardLogic.levelContext:getValue("importantSiteMap")
		if importantSiteMap.onCannonFalsify then 
			local params = { 
				itemList = itemList,
				gridPos = gridPos,
				setBlock = setBlock,
			}
			for _, runner in ipairs(importantSiteMap.onCannonFalsify) do 
				UBFFeatureHelper:doCommonRunner(gameBoardLogic, boardContext, runner, params)
				if params.isBlock then break end
			end
			itemList = params.itemList
		end
		gameBoardLogic:callById(gameBoardLogic.levelDiffChangeLogicId, "falsify", boardContext, itemList) 
	end

	local itemRawDataList = {}

	--
--


	for k , v in ipairs(itemList) do 
		v:setItemPos({ r = r , c = c })
		local itemContextRaw = v:getRawData()
		table.insert(itemRawDataList, itemContextRaw)
	end
	
	local gridContext = boardContext:getGridContextByPos(r, c)
	
	--偷速度
	local gridGravity = gridContext:getGravity()
	local currFallingIndex = 0 -- gridContext:getValue( "fallingIndex" )

	local fallingFrameRange = nil

    if gridContext:getValue("lastFallingType") == UBFGameFallingType.kAfterSide then --当前格的Item斜线掉落掉走了
		--检测左下和右下的格子，看看格子的来源是当前格，就用哪个格子的速度作为初始速度
		--[[
		local _fixR1 , _fixC1 , _fixR2 , _fixC2 = _getFallingByCannonSpdOPMap[gridGravity]( r , c )

		local _fallingIndex = nil
        
		local nextGridRaw = boardContext:getGridRawDataByPos( _fixR1 , _fixC1 )
        if nextGridRaw then 
			if nextGridRaw.lastFallingType == UBFGameFallingType.kSide and nextGridRaw.ffpR == r and nextGridRaw.ffpC == c then
				_fallingIndex = nextGridRaw.fallingIndex 
			end
		end

		if not _fallingIndex then
			nextGridRaw = boardContext:getGridRawDataByPos( _fixR2 , _fixC2 )
			if nextGridRaw then 
				if nextGridRaw.lastFallingType == UBFGameFallingType.kSide and nextGridRaw.ffpR == r and nextGridRaw.ffpC == c then
					_fallingIndex = nextGridRaw.fallingIndex 
				end
			end
		end

		if _fallingIndex then currFallingIndex = _fallingIndex end
		if currFallingIndex > 1 then currFallingIndex = 1 end
		]]

		currFallingIndex = 0
		fallingFrameRange = _fallingSpdMap[ currFallingIndex + 1 ] or _fallingSpdMap[#_fallingSpdMap]

    else
		-- 使用生成口所在格子的下一格的速度作为初始速度
        local vec = _G.GravityDirectionVecMap[gridGravity]
        local nextGridRaw = boardContext:getGridRawDataByPos( r + vec.r , c + vec.c )
        if nextGridRaw then currFallingIndex = nextGridRaw.fallingIndex end

		fallingFrameRange = _fallingSpdMap[ currFallingIndex + 1 ] or _fallingSpdMap[#_fallingSpdMap]
    end

	-- currFallingIndex = 4
	-- fallingFrameRange = _fallingSpdMap[ currFallingIndex + 1 ] or _fallingSpdMap[#_fallingSpdMap]

	local _fallingId = self:getNewFallingId()

	gridContext:fallingIn( nil , nil , itemRawDataList )

    local producer = {
        itemType = UBFGameItemType.kProducer,
        gridPos = gridPos,
    }
	UBFFeatureHelper:onItemsProduced(gameBoardLogic, boardContext, gridContext, itemRawDataList, producer)

	local tileDataList = {}

	for k , v in ipairs(itemList) do
		table.insert(tileDataList, v:getViewInfo())
		v:release()
	end

	gridContext:setValue( "fallingIndex" , currFallingIndex ) --出生速度index为0
	gridContext:setValue( "fallingState" , GridFallingState.kFalling )

    gridContext:setValue("lastFallingType", UBFGameFallingType.kCannon)
    gridContext:setValue("fallingId", _fallingId)

	-- local id = itemRawDataList[1].id
	-- if id == 102 then 
	-- 	local _rawData = gridContext._rawData
	-- 	watchObj( _rawData , { "fallingState" } , function( k , v )
	-- 		printx(21, k , v )
	-- 	end )
	-- end

	local datas = {
		fallingId = _fallingId,
		fallingType = UBFGameFallingType.kCannon,
		fallingIndex = currFallingIndex,
        r = r , c = c ,  
		dir = GravityDirectionToDirection[gridGravity],
		newTileList = tileDataList,
		frames = fallingFrameRange ,
		boardId = boardContext:getValue("boardId"),
    }

	-- if log then log("doFallingByCannon r:", r, "c:", c, "masterId =", gridContext:getItemMasterRawData().id) end
	gridContext:release()

	-- if _needtest then
	-- 	if log then log("doFallingByCannon r:", r, "c:", c, "gridGravity:", gridGravity, "dir:", GravityDirectionToDirection[gridGravity], "gridPos.r =", gridPos.r, "gridPos.c =", gridPos.r  ) end
	-- end
	
	self:updateVerticalFallingPlan( boardContext , gridPos.r , gridPos.c , true )
	
	local currLogicFrameIndex = self.gameBoardLogic:getCurrLogicFrameIndex()
	self.gameBoardLogic:createAndAddLogicAction(  UBFLogicActionType.kItemProduceToGrid , datas , currLogicFrameIndex + fallingFrameRange )

	local act = UBFViewActionData:create( 
											UBFViewActionType.kItemProduceToGrid , 
											datas , 
											currLogicFrameIndex,
											datas.boardId
										)

	table.insert( viewActlist , act )
end



local _checkFallingBySideBottomEmptyOpMap = { --todo
	[GravityDirection.kUp] = function ( selfObj , boardContext , r , c ) 
		return nil
	end ,
	[GravityDirection.kDown] = function ( selfObj , boardContext , r , c ) 
		return nil
	end ,
	[GravityDirection.kLeft] = function ( selfObj , boardContext , r , c  ) 
		return nil
	end ,
	[GravityDirection.kRight] = function ( selfObj , boardContext , r , c  ) 
		return nil
	end ,
}

--check_falling_by_side_bottom_empty
function UBFFallingItemLogicV2_1:checkFallingBySideBottomEmpty( boardContext  , r , c )


	-- local needPrint = false
	-- if r == 4 and c == 8 then
	-- 	needPrint = true
	-- end
	-- if needPrint then printx( 1 , "checkFallingBySideBottomEmpty  r" , r , "c" , c) end
	

	local gridRawData = boardContext:getGridRawDataByPos(r, c )
	local gridGravity = gridRawData.gravity

	-- if needPrint then printx( 1 , "checkFallingBySideBottomEmpty  r:" , r , "c:" , c  , "gridGravity:" , gridGravity ) end

	--[[
	local _datas = _checkFallingBySideBottomEmptyOpMap[gridGravity]( self , boardContext , r , c )
	--]]

	local nr = 0
	local nc = 0

	local fixr_right = 0
	local fixc_right = 0

	local fixr_left = 0
	local fixc_left = 0

	local posX_right = 0
	local posY_right = 0

	local posX_left = 0
	local posY_left = 0

	if gridGravity == GravityDirection.kDown then --todo move to opMap
		nr = r+1
		nc = c
		fixr_right = 1
		fixc_right = 1
		fixr_left = 1
		fixc_left = -1
		local nGridRawData = boardContext:getGridRawDataByPos( nr , nc ) --沿重力方向的下一个格子
		if nGridRawData and self:hasFallingBlockBetweenTwoVerticalGrids( gridRawData , nGridRawData ) then
			-- if needPrint then 
			-- 	printx( 1 , "checkFallingBySideBottomEmpty  return by GravityDirection.kDown")
			-- end
			return false
		end
	elseif gridGravity == GravityDirection.kUp then
		nr = r-1
		nc = c
		fixr_right = -1
		fixc_right = -1
		fixr_left = -1
		fixc_left = 1
		local nGridRawData = boardContext:getGridRawDataByPos( nr , nc )--沿重力方向的下一个格子
		if nGridRawData and self:hasFallingBlockBetweenTwoVerticalGrids( nGridRawData , gridRawData ) then
			-- if needPrint then 
			-- 	printx( 1 , "checkFallingBySideBottomEmpty  return by GravityDirection.kUp")
			-- end
			return false
		end
	elseif gridGravity == GravityDirection.kLeft then 
		nr = r
		nc = c-1
		fixr_right = 1
		fixc_right = -1
		fixr_left = -1
		fixc_left = -1
		local nGridRawData = boardContext:getGridRawDataByPos( nr , nc )--沿重力方向的下一个格子
		if nGridRawData and self:hasFallingBlockBetweenTwoHorizontalGrids( nGridRawData , gridRawData ) then
			-- if needPrint then 
			-- 	printx( 1 , "checkFallingBySideBottomEmpty  return by GravityDirection.kLeft")
			-- end
			return false
		end
	else
		nr = r
		nc = c+1
		fixr_right = -1
		fixc_right = 1
		fixr_left = 1
		fixc_left = 1
		local nGridRawData = boardContext:getGridRawDataByPos( nr , nc )--沿重力方向的下一个格子
		if nGridRawData and self:hasFallingBlockBetweenTwoHorizontalGrids( gridRawData , nGridRawData ) then
			-- if needPrint then 
			-- 	printx( 1 , "checkFallingBySideBottomEmpty  return by GravityDirection.kRight")
			-- end
			return false
		end
	end


	local fallingHelpMap = boardContext:getFallingHelpCacheMap()
	local vfPlan = fallingHelpMap.verticalFallingPlan

	-- if needPrint then 
	-- 	printx( 1 , "checkFallingBySideBottomEmpty  nr:" , nr , "nc:" , nc , "fixr_right:" , fixr_right , "fixc_right:" , fixc_right , "fixr_left:" , fixr_left , "fixc_left:" , fixc_left  )
	-- end
	

	local randomNum = UBFRandom:calcValue(boardContext:nextSeed("falling"), 1, 2) --todo

	local tr = 0
	local tc = 0
	local dir = 0  
	local poskey = 0

	-- if needPrint then 
	-- 	printx( 1 , "checkFallingBySideBottomEmpty  randomNum:" , randomNum )
	-- end


	if randomNum == 1 then
		--先右下再左下(注意，这里的方向指的是相对方向，即重力为下时的方向)
		tr = r + fixr_right
		tc = c + fixc_right
		poskey = tr * MACRO_POS_STRIDE + tc

		-- if needPrint then 
		-- 	printx( 1 , "checkFallingBySideBottomEmpty  111 poskey:" , poskey , "vfPlan[poskey]:" , vfPlan[poskey]  )
		-- 	printx( 1 , "checkFallingBySideBottomEmpty  aaa self:isGridCanBeFallingIn:" , self:isGridCanBeFallingIn( gridContext ) )
		-- end

		local nextGirdRawData = boardContext:getGridRawDataByPos( tr , tc )

		if nextGirdRawData 
			and ( not vfPlan[poskey] )
			and self:isGridCanBeFallingIn( nextGirdRawData )
			and ( not self:hasFallingBlockBetweenTwoObliqueVerticalGrids( boardContext , gridRawData , nextGirdRawData , 2) ) 
		then 	----右下方的格子可以被掉落进去
			dir = 2
		else
			tr = r + fixr_left
			tc = c + fixc_left
			poskey = tr * MACRO_POS_STRIDE + tc

			-- if needPrint then 
			-- 	printx( 1 , "checkFallingBySideBottomEmpty 222  poskey:" , poskey , "vfPlan[poskey]:" , vfPlan[poskey]  )
			-- 	printx( 1 , "checkFallingBySideBottomEmpty bbb  self:isGridCanBeFallingIn:" , self:isGridCanBeFallingIn( gridContext ) )
			-- end

			nextGirdRawData = boardContext:getGridRawDataByPos( tr , tc )

			if nextGirdRawData 
				and ( not vfPlan[poskey] )
				and self:isGridCanBeFallingIn( nextGirdRawData )
				and ( not self:hasFallingBlockBetweenTwoObliqueVerticalGrids( boardContext , gridRawData , nextGirdRawData , 1) ) 
			then 	----左下方的格子可以被掉落进去
				dir = 1
			else

			end
		end
		
	else
		--先左下再右下(注意，这里的方向指的是相对方向，即重力为下时的方向)
		tr = r + fixr_left
		tc = c + fixc_left
		poskey = tr * MACRO_POS_STRIDE + tc

		local nextGirdRawData = boardContext:getGridRawDataByPos( tr , tc )

		-- if needPrint then 
        -- 	printx( 1 , "checkFallingBySideBottomEmpty  333 poskey:" , poskey , "vfPlan[poskey]:" , vfPlan[poskey]  )
		-- 	printx( 1 , "checkFallingBySideBottomEmpty 先左下再右下  tr:" , tr , "tc:" , tc , "nextGirdContext:" , nextGirdContext  )
		-- end

		if nextGirdRawData 
			and ( not vfPlan[poskey] ) 
			and self:isGridCanBeFallingIn( nextGirdRawData )
			and ( not self:hasFallingBlockBetweenTwoObliqueVerticalGrids( boardContext , gridRawData , nextGirdRawData , 1) ) 
		then 	----左下方的格子可以被掉落进去
			dir = 1
		else
			tr = r + fixr_right
			tc = c + fixc_right
			poskey = tr * MACRO_POS_STRIDE + tc

            -- printx( 1 , "checkFallingBySideBottomEmpty  444 poskey:" , poskey , "vfPlan[poskey]:" , vfPlan[poskey]  )

			nextGirdRawData = boardContext:getGridRawDataByPos( tr , tc )

			if nextGirdRawData 
				and ( not vfPlan[poskey] )
				and self:isGridCanBeFallingIn( nextGirdRawData ) 
				and ( not self:hasFallingBlockBetweenTwoObliqueVerticalGrids( boardContext , gridRawData , nextGirdRawData , 2) ) 
			then ----右下方的格子可以被掉落进去
				dir = 2
			else

			end
		end
		
	end

	-- if needPrint then 
	-- 	printx( 1 , "checkFallingBySideBottomEmpty  randomNum:" , randomNum , "dir:" , dir , "tr:" , tr , "tc:" , tc  )
	-- end

	if not self:isInBoardBoarder( boardContext , tr , tc ) then 
		-- if needPrint then printx( 1 , "checkFallingBySideBottomEmpty  return 2" ) end
		return false 
	end

	return dir ~= 0 , dir , tr , tc
end

--do_falling_by_side_bottom_empty
function UBFFallingItemLogicV2_1:doFallingBySideBottomEmpty( boardContext  , r , c , tr , tc , viewActlist )

	-- printx( 1 , "UBFFallingItemLogicV2_1:doFallingBySideBottomEmpty  r:" , r , "c:" , c , "tr:" , tr , "tc:" , tc  )
	

	local fallingHelpMap = boardContext:getFallingHelpCacheMap()
	local vfPlan = fallingHelpMap.verticalFallingPlan

	local gridContext_start = boardContext:getGridContextByPos( r , c )
	local gridContext_end = boardContext:getGridContextByPos( tr , tc )

	local fallingItems = gridContext_start:getFallingableItemRawDatas()
	gridContext_start:removeItemContextByList( fallingItems )
	gridContext_end:fallingIn( r , c , fallingItems )

    gridContext_start:setValue("lastFallingType", UBFGameFallingType.kAfterSide)
    gridContext_end:setValue("lastFallingType", UBFGameFallingType.kSide)

	--减速安全，防止追尾
	-- local gVec = _G.GravityDirectionVecMap[gridContext_end:getGravity()]
	-- local mr , mc = tr + gVec.r , tc + gVec.c
	-- local gridContext_more = boardContext:getGridContextByPos( mr , mc )
	-- local maxFallingIndex
	-- if gridContext_more then 
	-- 	local fallingState = gridContext_more:getValue( "fallingState" )
	-- 	if fallingState ~= GridFallingState.kNormal then
	-- 		maxFallingIndex = gridContext_more:getValue("fallingIndex") 
	-- 	end
	-- 	gridContext_more:release()
	-- end

	gridContext_start:setValue( "fallingState" , GridFallingState.kNormal )
	gridContext_end:setValue( "fallingState" , GridFallingState.kFalling )

	local currFallingIndex = 0 --斜线掉落不再加速，永远为1

	-- if currFallingIndex > 1 then  
	-- 	currFallingIndex = 1 
	-- end

	local startFallingId = gridContext_start:getValue("fallingId") 

	if not startFallingId then
		startFallingId = self:getNewFallingId()
	end

	-- if maxFallingIndex and currFallingIndex > maxFallingIndex then currFallingIndex = maxFallingIndex end
    -- printx( 1 , "doFallingBySideBottomEmpty  currFallingIndex =" , currFallingIndex , r,c," --> " , tr,tc)
	gridContext_end:setValue( "fallingIndex" , currFallingIndex )
	gridContext_start:setValue("fallingIndex" , 0)

	gridContext_end:setValue( "fallingId" , startFallingId )
	gridContext_start:setValue("fallingId" , nil)
	
	local fallingFrameRange = _fallingSpdSide
	-- local fallingFrameRange = _fallingSpdMap[ currFallingIndex + 1 ] or _fallingSpdMap[#_fallingSpdMap]
	-- local fallingFrameRange = _fallingSpdMap[ 2 ]

	local currLogicFrameIndex = self.gameBoardLogic:getCurrLogicFrameIndex()
    local datas = {
		fallingId = startFallingId,
		fallingType = UBFGameFallingType.kSide,
		fallingIndex = currFallingIndex ,
		gravity = gridContext_start:getGravity(),
        r = r , c = c , tr = tr , tc = tc ,
		frames = fallingFrameRange ,
		boardId = boardContext:getValue("boardId"),
		fallingIds = UBFHelper:toList( fallingItems , function( v ) return v.id end ) ,
    }

	
	
    self.gameBoardLogic:createAndAddLogicAction(  UBFLogicActionType.kItemFallingToNextGrid , datas , currLogicFrameIndex + fallingFrameRange )
	
	-- printx( 1 , "doFallingByBottomEmpty  " , r , c , " >>> " , tr , tc , "  Start Falling , currLogicFrameIndex:" , currLogicFrameIndex , "need " ,fallingFrameRange , " frames" , " falling done at "  ,currLogicFrameIndex + fallingFrameRange )

	if viewActlist then
		local act = UBFViewActionData:create( 
											UBFViewActionType.kItemFallingToNextGrid , 
											datas , 
											currLogicFrameIndex,
											datas.boardId
										)

		table.insert( viewActlist , act )
	end

	
	local endGridGravity = gridContext_end:getGravity()

	-- if endGridGravity == GravityDirection.kDown then
	-- 	self:updateVerticalFallingPlan( boardContext , tr + 1 , tc , true )
	-- elseif endGridGravity == GravityDirection.kUp then
	-- 	self:updateVerticalFallingPlan( mainLogic , tr - 1 , tc , true )
	-- elseif endGridGravity == GravityDirection.kLeft then
	-- 	self:updateVerticalFallingPlan( mainLogic , tr , tc - 1 , true )
	-- else
	-- 	self:updateVerticalFallingPlan( mainLogic , tr , tc + 1 , true )
	-- end

	gridContext_start:release()
	gridContext_end:release()
end


--check_grid_is_portal_exit_and_just_empty
function UBFFallingItemLogicV2_1:checkGridIsPortalExitAndJustEmpty( boardContext , r ,c , viewActlist , backStop)

	local gridRawData = boardContext:getGridRawDataByPos( r , c )
	-- local itemContext = boardContext:getGridContextByPos( r , c )

	local exitPortalData = self:getGridExitPortalRawData(gridRawData)

    local checkResult = false

	if exitPortalData then -- 当前格子存在传送门出口
		local enterPos = exitPortalData.prevGridPos
		local enterGridRawData = boardContext:getGridRawDataByPos( enterPos.r , enterPos.c )
		if enterGridRawData then -- 找到对应的传送门入口
			if self:checkFallingByPortal( boardContext , enterGridRawData , enterPos.r , enterPos.c ) then -- 如果传送门入口所在格子的item可以被传送到当前格子
				-- 锁住当前格子一帧，避免后续流程被掉入item，确保下帧可以按预期优先级运行
				-- self:updateVerticalFallingPlan( boardContext , r , c , true ) --todo 可以再简化，不需要调用通用方法
                checkResult = true
				--还原
				if backStop then backStop(enterGridRawData) end
                -- printx( 1 , "checkGridIsPortalExitAndJustEmpty  doFallingByPortal ---- " , enterPos.r , enterPos.c )
                self:doFallingByPortal( boardContext , enterPos.r , enterPos.c , viewActlist )      --执行传送门传送
				--执行传送之后的递归处理
				self:doRecursionVFFalling( boardContext , enterPos.r , enterPos.c , viewActlist, true, backStop)     
			end
		end
	end

    return checkResult
end

function UBFFallingItemLogicV2_1:getVerticalFallingPlanMap()
	if not self.fallingPlanMap then self.fallingPlanMap = {} end
	if not self.fallingPlanMap.verticalFallingPlan then self.fallingPlanMap.verticalFallingPlan = {} end

	return self.fallingPlanMap.verticalFallingPlan
end

function UBFFallingItemLogicV2_1:clearVerticalFallingPlan()
	if not self.fallingPlanMap then self.fallingPlanMap = {} end
	self.fallingPlanMap.verticalFallingPlan = {}
end

local _updateVFPlanOpMap = {
	[GravityDirection.kUp] = function ( _self , _grid , _r , _c ) 
		-- return _r - 1 , _c , _self:hasBottomBorderFallingBlocker( _grid ) , _self:hasTopBorderFallingBlocker( _grid )
		return _r - 1 , _c , _self:hasTopBorderFallingBlocker( _grid )
	end ,
	[GravityDirection.kDown] = function ( _self , _grid , _r , _c ) 
		-- return _r + 1 , _c , _self:hasTopBorderFallingBlocker( _grid ) , _self:hasBottomBorderFallingBlocker( _grid )
		return _r + 1 , _c ,  _self:hasBottomBorderFallingBlocker( _grid )
	end ,
	[GravityDirection.kLeft] = function ( _self , _grid , _r , _c )
		-- return _r , _c - 1 , _self:hasRightBorderFallingBlocker( _grid ) , _self:hasLeftBorderFallingBlocker( _grid )
		return _r , _c - 1 , _self:hasLeftBorderFallingBlocker( _grid )
	end ,
	[GravityDirection.kRight] = function ( _self , _grid , _r , _c ) 
		-- return _r , _c + 1 , _self:hasLeftBorderFallingBlocker( _grid ) , _self:hasRightBorderFallingBlocker( _grid )
		return _r , _c + 1 , _self:hasRightBorderFallingBlocker( _grid )
	end ,
	[0] = function ( _self , _grid , _r , _c )
		printx( 1 , "Get Gravity Error At :" , _r , _c , debug.traceback() )
	end,
}

function UBFFallingItemLogicV2_1:_updateVFPlan( boardMap , vfPlan , _r , _c )
	
	local _rcid = (_r * MACRO_POS_STRIDE) + _c

	if vfPlan[_rcid] then
		return
	end

	-- local _item = itemMap[_r][_c]
	local _grid = boardMap[_r] and boardMap[_r][_c]
	if not _grid then return end
	
	local prevFallingBorderBlock = false
	local nextFallingBorderBlock = false
	local nextR = 0
	local nextC = 0

	local nextR , nextC , nextFallingBorderBlock = _updateVFPlanOpMap[ _grid.gravity ]( self , _grid , _r , _c )
	

	if ( not _grid.isUsed ) or ( not _grid.isMasterCanFalling and _grid.passVerFallingPlanUpdate <= 0 ) then
		-- 格子未启用，或格子里的Materitem无法掉落，则本格不锁，递归结束，最后一个锁住的是上一格
		return
	end

	vfPlan[_rcid] = true --锁住当前格（预分配当前格的掉落）

	if nextFallingBorderBlock then
		-- 去往下一格的边缘存在fallingBlock，递归结束
		return
	end

	local enterPortalRawData = self:getGridEnterPortalRawData( _grid )

	if enterPortalRawData then --格子上有传送门入口

		local _nextGridPos = enterPortalRawData.nextGridPos
		self:_updateVFPlan( boardMap , vfPlan , _nextGridPos.r , _nextGridPos.c ) --跳转到传送门的出口格子，继续遍历
		return
	end

	if boardMap[nextR] and boardMap[nextR][nextC] then 
		
		local nextGrid = boardMap[nextR][nextC]     -- 获取 沿重力方向的 下一格
		if nextGrid.gravity == _grid.gravity then	-- 下一格 的 重力方向没有变化
			self:_updateVFPlan( boardMap , vfPlan , nextR , nextC ) -- 跳转到下一格，继续递归
			return
		end
	end
end

--update_vertical_falling_plan
function UBFFallingItemLogicV2_1:updateVerticalFallingPlan( boardContext , r , c , isFirstGrid )

	isFirstGrid = true --todo tbremove

	local fallingHelpCacheMap = boardContext:getFallingHelpCacheMap()
	local vfPlan = fallingHelpCacheMap.verticalFallingPlan

	if vfPlan then

		local rcid = (r * MACRO_POS_STRIDE) + c
		if vfPlan[ rcid ] then
			return
		end

		local boardMap =  boardContext:getBoardMap()
		local gridRawdata = boardMap[r][c]
		-- local border =  boardContext:getBoardBorder( true )

		-- --todo  迁移到getGridPosMap里判断
		-- if r < border.top or r > border.bottom or c < border.left or c > border.right then
		-- 	return --出边界不处理
		-- end

		if not gridRawdata then return end

		if not gridRawdata.inBorder then return end

		if not gridRawdata.isUsed then return end

		self:_updateVFPlan( boardMap , vfPlan , r , c , isFirstGrid )
	end
end

-- 函数的seed通常传入，保证一个函数同样的seed运行结果一致
function UBFFallingItemLogicV2_1:updateFallingOrderRandomList(boardContext , seed)

	-- boardContext:resetFallingHelpCacheMap()
	local seed = seed or 1234567

	local function nextSeed()
		seed = UBFRandom:nextSeed( seed )
		return seed
	end

	local fallingHelpMap = boardContext:getFallingHelpCacheMap()

	local randomColList = {}
	local randomRowList = {}

	local boardBorder = boardContext:getBoardBorder(true)

	local topBorder = boardBorder.top
	local bottomBorder = boardBorder.bottom
	local leftBorder = boardBorder.left
	local rightBorder = boardBorder.right

	local arr = {}
	for idx = leftBorder , rightBorder do
		table.insert(arr, idx)
	end
	for i = leftBorder , rightBorder do
		local cindex = UBFRandom:calcValue(nextSeed(), 1, #arr)
		-- printx( 1 , "cindex =" , cindex  , "#arr =" , #arr , table.serialize(arr) )
		table.insert(randomColList , arr[cindex])
		table.remove(arr, cindex)
	end

	if (bottomBorder - topBorder) == (rightBorder - leftBorder) then
		randomRowList = randomColList	--不影响老逻辑：如行列相同，则同一队列公用
	else
		local arr2 = {}
		for idx = topBorder , bottomBorder do
			table.insert(arr2, idx)
		end
		for i = topBorder , bottomBorder do
			local rindex = UBFRandom:calcValue( nextSeed() , 1 , #arr2 )
			table.insert( randomRowList , arr2[rindex] )
			table.remove( arr2 , rindex )
		end
	end

	local gravityDownArr = {}
	local gravityUpArr = {}
	local gravityLeftArr = {}
	local gravityRightArr = {}

	-- local opMap = {
	-- 	[GravityDirection.kUp] = function ( r , c ) 
	-- 		table.insert( gravityUpArr , { r = r , c = c } )
	-- 	end ,
	-- 	[GravityDirection.kDown] = function ( r , c ) 
	-- 		table.insert( gravityDownArr , 1 , { r = r , c = c } )
	-- 	end ,
	-- 	[GravityDirection.kLeft] = function ( r , c ) 
	-- 		table.insert( gravityLeftArr , { r = r , c = c }  )
	-- 	end ,
	-- 	[GravityDirection.kRight] = function ( r , c ) 
	-- 		table.insert( gravityRightArr , 1 , { r = r , c = c }  )
	-- 	end ,
	-- 	[0] = function ( r , c )
	-- 		printx( 1 , "Get Gravity Error At :" , r , c , debug.traceback() )
	-- 	end,
	-- }

	for r = topBorder , bottomBorder do			---- ↓：由下至上； ↑：由上至下
		for _k , c in ipairs( randomColList ) do              ----横排随机取
			local _gravity = boardContext:getGridGravityByPos( r , c )
			if _gravity == GravityDirection.kUp then
				table.insert( gravityUpArr , { r = r , c = c } )
			elseif _gravity == GravityDirection.kDown then
				table.insert( gravityDownArr , 1 , { r = r , c = c } )
			end
		end
	end

	for c = leftBorder , rightBorder do			---- ←：由左至右； →：由右至左
		for _k , r in ipairs( randomRowList ) do              ----竖列随机取
			local _gravity = boardContext:getGridGravityByPos( r , c )
			if _gravity == GravityDirection.kLeft then
				table.insert( gravityLeftArr , { r = r , c = c }  )
			elseif _gravity == GravityDirection.kRight then
				table.insert( gravityRightArr , 1 , { r = r , c = c }  )
			end
		end
	end

	-- 对四个重力方向的处理顺序进行随机
	local _arr = {1,2,3,4}
	local _randomArr = {} --每次都重置随机队列

	for i = 1 , 4 do
		local rindex = UBFRandom:calcValue( nextSeed() , 1 , #_arr )
		table.insert( _randomArr , _arr[rindex] )
		table.remove( _arr , rindex )
	end

	local resultArr = {}

	local opMap2 = {
		[GravityDirection.kUp] = function () 
			table.insert( resultArr , gravityUpArr )
		end ,
		[GravityDirection.kDown] = function () 
			table.insert( resultArr , gravityDownArr )
		end ,
		[GravityDirection.kLeft] = function () 
			table.insert( resultArr , gravityLeftArr )
		end ,
		[GravityDirection.kRight] = function () 
			table.insert( resultArr , gravityRightArr )
		end ,
	}

	for i = 1 , 4 do
		opMap2[ _randomArr[i] ]()
	end

	local maxGravityArrLength = 0
	if #gravityDownArr > maxGravityArrLength then maxGravityArrLength = #gravityDownArr end
	if #gravityUpArr > maxGravityArrLength then maxGravityArrLength = #gravityUpArr end
	if #gravityLeftArr > maxGravityArrLength then maxGravityArrLength = #gravityLeftArr end
	if #gravityRightArr > maxGravityArrLength then maxGravityArrLength = #gravityRightArr end

	-- printx( 1, "resultArr = " , tts(resultArr) )

	fallingHelpMap.fallingRandomPosArr = resultArr
	fallingHelpMap.maxGravityArrLength = maxGravityArrLength
	fallingHelpMap.randomColList = randomColList
	fallingHelpMap.randomRowList = randomRowList

end

local _updateVFPByVerticalFallingOPMap = {

	[GravityDirection.kUp] = function ( _self , boardContext , r , c ) 
		_self:updateVerticalFallingPlan( boardContext , r - 1 , c , true )
	end ,
	[GravityDirection.kDown] = function ( _self , boardContext , r , c ) 
		_self:updateVerticalFallingPlan( boardContext , r + 1 , c , true )
	end ,
	[GravityDirection.kLeft] = function ( _self , boardContext , r , c ) 
		_self:updateVerticalFallingPlan( boardContext , r , c - 1 , true )
	end ,
	[GravityDirection.kRight] = function ( _self , boardContext , r , c ) 
		_self:updateVerticalFallingPlan( boardContext , r , c + 1 , true )
	end ,
	[0] = function ( _self , r , c )
		printx( 1 , "Get Gravity Error At :" , r , c , debug.traceback() )
	end,

}

--check_item_falling
function UBFFallingItemLogicV2_1:checkItemFalling(levelContext, boardId)

    local _needtest = false

	local viewActlist = {}

	local boardContext = levelContext:getBoardContext(boardId)
	local boardMap = boardContext:getBoardMap()

	if boardContext:getValue("updateFallingOrderFlag") then 
		self:updateFallingOrderRandomList(boardContext, boardContext:nextSeed("falling"))
		boardContext:setValue("updateFallingOrderFlag", false)
	end

	local currLogicFrameIndex = self.gameBoardLogic:getCurrLogicFrameIndex()


	-- local itemMap = mainLogic:getItemMap()
	-- local boardMap = mainLogic:getBoardMap()

	-- local currHoldrand = mainLogic.randFactory:getCurrHoldrand()
	-- mainLogic.fallingLogicRandFactory:randSeed(currHoldrand)

	-- boardContext:resetFallingHelpCacheMap()
	local fallingHelpMap = boardContext:getFallingHelpCacheMap()
	-- local fallingHelpMap = self.fallingPlanMap.verticalFallingPlan
	-- printx( 1 , "UBFFallingItemLogicV2_1:checkItemFalling ----全局检测掉落-----" )

	local isStillFalling = false

	local maxGravityArrLength = fallingHelpMap.maxGravityArrLength
	local gravityArrSortList = fallingHelpMap.fallingRandomPosArr
	local vfPlan = {}
	fallingHelpMap.verticalFallingPlan = vfPlan
	
	-- printx( 1 , "gravityArrSortList = \n" , table.serialize(gravityArrSortList))

    local _doneMap = {}
    local _noneDoCount = 0
    local _needCheckMap = {}

	----第一次遍历，处理传送门
	for i = 1 , maxGravityArrLength do
		for ia = 1 , #gravityArrSortList do
			local gravityArr = gravityArrSortList[ia]
			if gravityArr[i] then

				local pos = gravityArr[i]
				local r = pos.r
				local c = pos.c

				local gridRawData = boardMap[r][c]
				-- local gridContext = UBFContextManager:pack( gridRawData )
			
                -- printx( 1 , "checkItemFalling   checkFallingByPortal" , r,c )
				if self:checkFallingByPortal(boardContext, gridRawData, r, c) then
					-- printx( 1 , "checkItemFalling   doFallingByPortal" , r,c )
                    self:doFallingByPortal(boardContext, r, c, viewActlist)        --执行传送门传送
					self:checkGridIsPortalExitAndJustEmpty(boardContext, r, c, viewActlist, nil)
					isStillFalling = true
				end
			end
		end
	end

	local stopItemGridPosMap = {}

	local function backStop(gridRawData)
		local pos = gridRawData.pos
		local key = pos.r * MACRO_POS_STRIDE + pos.c
		if stopItemGridPosMap and stopItemGridPosMap[key] then
			gridRawData.fallingId = stopItemGridPosMap[key].fallingId
			stopItemGridPosMap[key] = nil
		end
	end

	----直线掉落
	for i = 1 , maxGravityArrLength do
		for ia = 1 , #gravityArrSortList do
			local gravityArr = gravityArrSortList[ia]
			-- if log then 
			-- 	if (gravityArr[i] and gravityArr[i].r == 9 and gravityArr[i].c == 2) or (gravityArr[i] and gravityArr[i].r == 8 and gravityArr[i].c == 2) then
			-- 		_needtest = true
			-- 	else
			-- 		_needtest = false
			-- 	end
			-- end
			-- if _needtest then log( 1 , "直线掉落 ----- 1    gravityArr[i] =" , gravityArr[i] , " i=" ,i ) end

			if gravityArr[i] then

				local pos = gravityArr[i]
				local r = pos.r
				local c = pos.c

				local gridRawData = boardMap[r][c]

                if gridRawData.fallingState ~= GridFallingState.kFalling then --todo falling  item:checkCanFallingByItemStatus()

                    -- if _needtest then printx( 1 , "checkFallingByBottomEmpty  ---- " , r , c  ) end
                    if self:checkFallingByBottomEmpty(boardContext, gridRawData, r, c) then

                        -- if _needtest then printx( 1 , "doFallingByBottomEmpty  ---- " , r , c) end
                        self:doFallingByBottomEmpty( boardContext , r , c , viewActlist )

                        local gravity = gridRawData.gravity

                        _updateVFPByVerticalFallingOPMap[ gravity ]( self , boardContext , r , c )

                        self:checkGridIsPortalExitAndJustEmpty( boardContext , r , c , viewActlist , backStop) --当前格发生掉落后，产生的空格子需要立刻检测传送门，否则可能被后续的斜向掉落占住
                        isStillFalling = true

                    else
                        local key = r * MACRO_POS_STRIDE + c
                        if gridRawData.fallingState == GridFallingState.kJustArrive --[[and not gridRawData.fromSideFalling]] then
							local fallingItems = UBFGridContext:rawCall(gridRawData, "getFallingableItemRawDatas")
							-- printx(21, "arrive" , currLogicFrameIndex, gridRawData.fallingId)
							stopItemGridPosMap[key] = { 
								r = r , c = c , 
								fallingId = gridRawData.fallingId ,
								fallingIds = UBFHelper:toList( fallingItems , function( v ) return v.id end ) ,
							}
                            -- self:doFallingStop( boardContext , r , c )
							-- printx( 21 , "kJustArrive ---> kHalfStable  :" , currLogicFrameIndex, r,c , gridRawData.fallingId )
                            if _needtest then printx( 1 , "kJustArrive ---> kHalfStable  :" , r,c ) end
                            gridRawData.fallingState = GridFallingState.kHalfStable --如果无法继续掉落了，状态又是kJustArrive，则
							gridRawData.fallingId = nil
						else
							-- if _needtest then printx( 1 , "Not kJustArrive,  pass ..." , r,c ) end
						end
						if gridRawData.passVerFallingPlanUpdate > 0 then 
							self:updateVerticalFallingPlan( boardContext , r , c , true )
						end
                    end
                else
					-- if _needtest then printx( 1 , "Now is kFalling,  updateVerticalFallingPlan " , r,c ) end
                    self:updateVerticalFallingPlan( boardContext , r , c , true )
                end

				-- if _needtest then printx( 1 , "直线掉落 ----- FIN --------------- \n\n\n\n" ) end
			end
		end
	end

	--生成口决策
	local producers = {}

	-- local producerRepeatMap = {}
	for i = 1 , maxGravityArrLength do
		for ia = 1 , #gravityArrSortList do
			local gravityArr = gravityArrSortList[ia]
			if gravityArr[i] then

				local pos = gravityArr[i]
				local r = pos.r
				local c = pos.c
				local key =  r * MACRO_POS_STRIDE + c

				-- if producerRepeatMap[key] then
				-- 	printx(21, "hhhhh")
				-- end

				if (not vfPlan[key] ) then
					-- producerRepeatMap[key] = true

					local gridRawData = boardMap[r][c]
					local producerList = gridRawData[UBFGridContext.itemTypeMapKey][UBFGameItemType.kProducer]
					local producer = producerList and producerList[1]
					if producer and self:checkFallingByCannon(boardContext, r, c) then 
						table.insert( producers , { r = r, c = c } ) 
					end
				end
			end
		end
	end
				
	-- 生成口实际执行
	if #producers > 0 then
		-- local sortedProductPortals = mainLogic:sortProductPortals(producers)
		local sortedProductPortals = producers
		for _, gridPos in ipairs(sortedProductPortals) do
			self:doFallingByCannon( boardContext , gridPos.r , gridPos.c , viewActlist )
		end
		isStillFalling = true
	end

	----[[

	----斜线掉落
	-- print("UBFFallingItemLogicV2_1:checkItemFalling()Slash-0")
    -- printx( 1 , "斜线掉落 ---------------------------")
	for i = 1 , maxGravityArrLength do
		for ia = 1 , #gravityArrSortList do
			local gravityArr = gravityArrSortList[ia]
			-- print("UBFFallingItemLogicV2_1:checkItemFalling()Slash-iv-0",i,ia)
			if gravityArr[i] then

				local pos = gravityArr[i]
				local r = pos.r
				local c = pos.c
				local key =  r * MACRO_POS_STRIDE + c

				-- local _needtest = false
				-- if r == 1 and c == 1 then
				-- 	_needtest = true
				-- end

				local gridRawData = boardMap[r][c]
                local fallingState = gridRawData.fallingState

				-- if _needtest then printx( 1 , "UBFFallingItemLogicV2_1 FallingBySide 1 -----:",r,c) end

				if (fallingState == GridFallingState.kNormal or fallingState == GridFallingState.kJustArrive) and self:isGridCanBeFallingOut( gridRawData ) then

					-- if _needtest then printx( 1 , "UBFFallingItemLogicV2_1 FallingBySide 2 -----:",r,c) end
					if self:checkFallingByBottomEmpty( boardContext , gridRawData , r , c ) then --斜线掉落也要先检查正下方是否能掉落，因为下方的格子发生斜线掉落后，上方格子也许可以执行直线掉落
						-- if log then log( 1 , "UBFFallingItemLogicV2_1 FallingBySide 3 -----:",r,c) end
						
						--如果之前暂停了，这里取消暂停
						backStop(gridRawData)

						self:doFallingByBottomEmpty( boardContext , r , c , viewActlist )


						-- 当前格发生掉落后，产生的空格子需要立刻检测 传送门 和 生成口 ，否则可能被后续的斜向掉落占住
						local _result = self:checkGridIsPortalExitAndJustEmpty( boardContext , r , c , viewActlist , backStop) 
                        if not _result then
                            if not self:doRecursionVFFalling( boardContext , r , c , viewActlist, nil, backStop ) then
								local producerList = gridRawData[UBFGridContext.itemTypeMapKey][UBFGameItemType.kProducer]
								local producer = producerList and producerList[1]
								if producer then
									-- printx( 1 , "斜线掉落  after  producer = " , producer , r,c )
									if self:checkFallingByCannon( boardContext , r, c ) then 
										self:doFallingByCannon( boardContext , r , c , viewActlist )
									end
								end
							end
                        end
						isStillFalling = true
						-- vfPlan[key] = true
					else
						
						local result , dir , tr ,tc = self:checkFallingBySideBottomEmpty( boardContext , r , c )
						-- if _needtest then printx( 1 , "UBFFallingItemLogicV2_1 FallingBySide 4 -----:",r,c , result , dir , tr ,tc ) end

						if result then
							-- if log then log( 1 , "UBFFallingItemLogicV2_1 FallingBySide 5 -----:",r,c , "->",tr,tc) end
							self:doFallingBySideBottomEmpty( boardContext , r , c , tr , tc , viewActlist )

                            -- 当前格发生掉落后，产生的空格子需要立刻检测 传送门 和 生成口 ，否则可能被后续的斜向掉落占住
                            local _result = self:checkGridIsPortalExitAndJustEmpty( boardContext , r , c , viewActlist, backStop) 
                            
                            if not _result then
                                if not self:doRecursionVFFalling( boardContext , r , c , viewActlist , nil, backStop) then
									local producerList = gridRawData[UBFGridContext.itemTypeMapKey][UBFGameItemType.kProducer]
									local producer = producerList and producerList[1]
									if producer then
										-- printx( 1 , "斜线掉落  after  producer = " , producer , r,c )
										if self:checkFallingByCannon( boardContext , r, c ) then 
											self:doFallingByCannon( boardContext , r , c , viewActlist )
										end
									end
								end
                            end

							isStillFalling = true
							-- vfPlan[key] = true

						else
							if fallingState == GridFallingState.kJustArrive then
                                -- printx( 1 , "UBFFallingItemLogicV2_1 FallingBySide 6 -----:",r,c)
								local fallingItems = UBFGridContext:rawCall(gridRawData, "getFallingableItemRawDatas")
								stopItemGridPosMap[key] = { 
									r = r , c = c , 
									fallingId = gridRawData.fallingId ,
									fallingIds = UBFHelper:toList( fallingItems , function( v ) return v.id end ) ,
								}
								gridRawData.fallingState = GridFallingState.kHalfStable
								gridRawData.fallingId = nil
							end
						end
					end
				end
			end
		end
	end

	--]]

	--发送所有停下来的动画信息
	self:doStopActions( boardContext , stopItemGridPosMap , viewActlist )

	--统一发送！
	self.gameBoardLogic:sendViewActionList( viewActlist )

	
	boardContext:release()

    -- if _needtest then printx( 1 , "UBFFallingItemLogicV2_1 isStillFalling ",isStillFalling) end
	return isStillFalling
end