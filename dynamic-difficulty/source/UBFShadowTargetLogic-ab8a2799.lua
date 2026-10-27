UBFShadowTargetLogic = class2( "UBFShadowTargetLogic" , UBFBaseLogic )
UBFShadowTargetLogic.shadowTargetsKey = "shadowTargets"


UBFShadowTargetLogic.DebugMode = true


function UBFShadowTargetLogic:build( createData )
    self.gameBoardLogic = createData.gameBoardLogic
    self.levelContext = self.gameBoardLogic.levelContext
    self.boardId = 1

end

function UBFShadowTargetLogic:gameInit( createData )

    local shadowTargetData = {
    	progressDataList = {},
    	shadowTargetsMap = {},
    	watchEvents = {},
		staticTypes = {
	    	[UBFShadowTargetStatisticType.kBase] = true,
	    	[UBFShadowTargetStatisticType.kBanding] = true,
	    }
    }
    self.levelContext:setValue( UBFShadowTargetLogic.shadowTargetsKey  , shadowTargetData )



    local levelConfig = createData.levelConfig
	local featureMap = createData.featureMap

    self:registerWatchShadowTargets(featureMap)
	self:doWatchInit()
	self:calGlobalShadowTarget()
    self:pushTakeStepProgressData()
end

function UBFShadowTargetLogic:getShadowTargetsMap( ... )
	local context = self.levelContext:getValue( UBFShadowTargetLogic.shadowTargetsKey)
    local shadowTargetsMap = context and context.shadowTargetsMap

    return shadowTargetsMap
end

function UBFShadowTargetLogic:getProgressDataList( ... )
	local context = self.levelContext:getValue( UBFShadowTargetLogic.shadowTargetsKey)
    local progressDataList = context and context.progressDataList
    return progressDataList
end

function UBFShadowTargetLogic:getWatchEvents( ... )
	local context = self.levelContext:getValue( UBFShadowTargetLogic.shadowTargetsKey)
    local watchEvents = context and context.watchEvents
    return watchEvents
end

function UBFShadowTargetLogic:getStaticTypes( ... )
	local context = self.levelContext:getValue( UBFShadowTargetLogic.shadowTargetsKey)
    local staticTypes = context and context.staticTypes
    return staticTypes
end


function UBFShadowTargetLogic:isStaticType( type )
	local staticTypes = self:getStaticTypes()
	return 	staticTypes[type]
end


function UBFShadowTargetLogic:registerWatchShadowTargets( featureMap )
	local watchEvents = self:getWatchEvents()
	local shadowTargetsMap = self:getShadowTargetsMap()
    for shadowTargetType , watchConfigs in pairs(UBFShadowTargetConfig) do 
    	local needWatch = false
    	local watchDataList = {}
    	-- printx(16,shadowTargetType)
		assert(type(watchConfigs)=="table","watchConfigs NOT table at:"..tostring(shadowTargetType) .. "-value:".. tostring(watchConfigs))
		for index,watchConfig in ipairs(watchConfigs) do
			-- self:registerWatchShadowTarget(watchConfig)
			local itemType = watchConfig.watch.itemType
			local headItemType = watchConfig.watch.headItemType 
			local bindingItemType = watchConfig.watch.bindingItemType 

			local eventName = watchConfig.watch.UBFGamePlayEventEnum
			if eventName then
				watchEvents[eventName] = true
			end
			needWatch = needWatch or self:isNeedWatch(watchConfig,featureMap)

			local watchData = { enable = true,cur = 0,curMap = {},initNum = nil}
			watchDataList[index] = watchData
		end
		if needWatch then
			shadowTargetsMap[shadowTargetType] = watchDataList
		end

    end
end

function UBFShadowTargetLogic:isNeedWatch( watchConfig,featureMap )
	local itemType = watchConfig.watch.itemType
	local headItemType = watchConfig.watch.headItemType 
	local bindingItemType = watchConfig.watch.bindingItemType 

	local checkFeatureMap = function ( itemType )
		return featureMap[itemType]
	end

	if bindingItemType and not(checkFeatureMap(bindingItemType)) then return false end
	if itemType and not(checkFeatureMap(itemType)) then return false end
	if headItemType and not(checkFeatureMap(headItemType)) then return false end

	-- printx(16,bindingItemType,itemType,headItemType,tts(watchConfig))

	return true
end



-- function UBFShadowTargetLogic:_calPathBanding( itemType,pathItemType )
-- 	local boardContext = self.levelContext:getBoardContext(self.boardId)

--     local baseItemRaws = boardContext:filter({
--         isGlobal = true,
--         itemType = itemType, 
--     })
--     local progress = 0
--     for _,itemRaw in ipairs(baseItemRaws) do 
--     	progress = progress + self:getPathPos(pos,pathItemType)
--     end
--     boardContext:release()

--     return progress
-- end

function UBFShadowTargetLogic:getPathPos( pos,pathItemType )
	local boardContext = self.levelContext:getBoardContext(self.boardId)
    local progress = 0
	local pathItemContext = boardContext:getItemContextByPosType(pos,pathItemType)
	if pathItemContext then
		progress = progress + pathItemContext:getRawData().route.index - 1
		pathItemContext:release()
	end
    boardContext:release()

    return progress
end

-- 当前距离路径终点的剩余距离
function UBFShadowTargetLogic:getPathPosToEnd(pos, pathItemType)
	local boardContext = self.levelContext:getBoardContext(self.boardId)
    local progress = 0
	local pathItemContext = boardContext:getItemContextByPosType(pos, pathItemType)	--多条路径时，这里会随机取一条
	if pathItemContext then
		local routeItemData = pathItemContext:getRawData().route
		if routeItemData and routeItemData.routeRef then
			local routeData = routeItemData.routeRef
			local wholeRouteLength = routeData.initLength
			local leftLength = wholeRouteLength - routeItemData.index
			progress = progress + leftLength
		end
		pathItemContext:release()
	end
    boardContext:release()

    return progress
end

function UBFShadowTargetLogic:calLine(  )
	local boardContext = self.levelContext:getBoardContext(self.boardId)

	local tmp = {}
	for k,v in pairs(self.dynamicStatisticsTargets) do 
		local watchConfigs = UBFShadowTargetConfig[k]
		local cur = 0
		for _,watchConfig in ipairs(watchConfigs) do 
			if watchConfig.watch.type == UBFShadowTargetStatisticType.kCalculateRow then
				local itemType = watchConfig.watch.itemType
				local direction = watchConfig.watch.direction
				local progress = self:_calRow(itemType,direction)
				cur = cur + progress
			elseif watchConfig.watch.type == UBFShadowTargetStatisticType.kCalculateCol then
				local itemType = watchConfig.watch.itemType
				local direction = watchConfig.watch.direction
				local progress = self:_calCol(itemType,direction)
				cur = cur + progress
			end
		end
		if cur > 0 then tmp[k] = cur end
	end
	for k,v in pairs(tmp) do 
		self.dynamicStatisticsTargets[k].cur = v
	end
	boardContext:release()
end

function UBFShadowTargetLogic:_calRow( itemType,direction )
	local boardContext = self.levelContext:getBoardContext(self.boardId)
	local rowMap = {}
    local baseItemRaws = boardContext:filter({
        isGlobal = true,
        itemType = itemType, 
    })
    for _,itemRaw in ipairs(baseItemRaws) do
    	rowMap[itemRaw.pos.r] = true
    end

    local boardSize = boardContext:getBoardSize()
    local ret = 0
    if direction ~= UBFDirection.kDown then
	    for row = boardSize.height , 1, -1 do
	    	if rowMap[row] then 
	    		ret = row
	    		break
	    	end
	    end
    else
	    for row = 1 , boardSize.height do
	    	if rowMap[row] then 
	    		ret = row
	    		break
	    	end
	    end
	 end

	boardContext:release()

	return ret
end

function UBFShadowTargetLogic:_calCol( itemType,direction )
	local boardContext = self.levelContext:getBoardContext(self.boardId)
	local colMap = {}
    local baseItemRaws = boardContext:filter({
        isGlobal = true,
        itemType = itemType, 
    })
    for _,itemRaw in ipairs(baseItemRaws) do
    	colMap[itemRaw.pos.c] = true
    end

    local boardSize = boardContext:getBoardSize()
    local ret = 0
    if direction ~= UBFDirection.kRight then
	    for col = 1 , boardSize.width do
	    	if colMap[col] then 
	    		ret = col
	    		break
	    	end
	    end
    else
	    for col = 1 , boardSize.width do
	    	if colMap[col] then 
	    		ret = col
	    		break
	    	end
	    end
	end

	boardContext:release()

	return ret
end


function UBFShadowTargetLogic:calBoard(  )
	local boardContext = self.levelContext:getBoardContext(self.boardId)

	local tmp = {}
	for k,v in pairs(self.dynamicStatisticsTargets) do 
		local watchConfigs = UBFShadowTargetConfig[k]
		local cur = 0
		for _,watchConfig in ipairs(watchConfigs) do 
			-- printx(16,watchConfig.watch.type,"watchConfig.watch.type")
			if watchConfig.watch.type == UBFShadowTargetStatisticType.kCalculateViewVoard then
				local itemType = watchConfig.watch.itemType
				local progress = self:_calBoard(itemType,watchConfig.watch.fieldsCheck,false)
				cur = cur + progress
				-- printx(16,"calBoard",progress)
			elseif watchConfig.watch.type == UBFShadowTargetStatisticType.kCalculateAllVoard then
				local itemType = watchConfig.watch.itemType
				local progress = self:_calBoard(itemType,watchConfig.watch.fieldsCheck,true)
				cur = cur + progress
				-- printx(16,"calBoard x",progress)
			end
		end
		if cur > 0 then tmp[k] = cur end
	end

	for k,v in pairs(tmp) do 
		self.dynamicStatisticsTargets[k].cur = v
	end
	boardContext:release()
end


function UBFShadowTargetLogic:_calBoard( itemType,fieldsCheck,isGlobal )
	local boardContext = self.levelContext:getBoardContext(self.boardId)

	local filterData = {
		isGlobal = isGlobal,
        itemType = itemType,
        fieldCond = {}

	}
	for k,check in ipairs(fieldsCheck or {}) do 
		if check.value then
			table.insert(filterData.fieldCond,{
				field = check.field,
				mode = UBFBoardFilterConst.kValue,
				val = check.value
			})
		elseif check.range then
			table.insert(filterData.fieldCond,{
				field = check.field,
				mode = UBFBoardFilterConst.kRange,
				min = check.range[1] , 
				max = check.range[2] ,
			})
		end
	end
    local baseItemRaws = boardContext:filter(filterData)


    if baseItemRaws then
    	return #baseItemRaws
    else
    	return 0
    end

    boardContext:release()
end








----------------------计算影子目标的时机

function UBFShadowTargetLogic:onEnterWaiting( boardContext )
	self:reInitWatch()
	self:calGlobalShadowTarget()
	self:pushTakeStepProgressData()
end

function UBFShadowTargetLogic:genStepProgressList( ... )
	local shadowTargetsMap = self:getShadowTargetsMap()
	local progressList = {}
	for shadowTargetType,watchDataList in pairs(shadowTargetsMap) do 
		local cur = 0

		for _,watchData in ipairs(watchDataList) do 
			if watchData.flipNum then
				cur = cur + watchData.flipNum
			else
				cur = cur + watchData.cur
			end

			if watchData.flipNumMap then
				for _,value in pairs(watchData.flipNumMap) do 
					cur = cur + value
				end
			else
				for _,value in pairs(watchData.curMap) do 
					cur = cur + value
				end
			end
			
			-- printx(16,"genStepProgressList",cur,tts(watchData))

		end


		table.insert(progressList,{
			cv = cur,
			id = shadowTargetType,
			tv = 0,
			shadow = true, 
			isDone = true,
			isFuuuDone = true,
		})
	end
	return progressList
end

function UBFShadowTargetLogic:pushTakeStepProgressData( ... )
	-- body
	local progressDataList = self:getProgressDataList()
	local step = self.gameBoardLogic:leagueCall( "getMoveCount" )
	local staticStep = self.gameBoardLogic:leagueCall( "getStaticMoveCount" )
	-- if step > staticStep then return nil end --不急了超过最大步数的
	-- printx(16,step,"xxxxxxxxxxxx",debug.traceback())
	progressDataList[step] = {
		list = self:genStepProgressList(),
		restMove = self.gameBoardLogic:leagueCall( "getRestMoveCount" )
	}

end


function UBFShadowTargetLogic:checkBindingItemType( watchConfig,itemContextRaw )
	if not watchConfig then return end
	if not watchConfig.watch then return end
	--没有绑定直接返回true
	if not watchConfig.watch.bindingItemType then return true end

	local boardContext = self.levelContext:getBoardContext(self.boardId)
	local bindingItemType = watchConfig.watch.bindingItemType
	local itemContext = boardContext:getItemContextByPosType( itemContextRaw.pos,bindingItemType)

	if not itemContext then
		local pos = itemContextRaw.pos
		local gridContext = boardContext:getGridContextByPos( pos.r , pos.c , pos.d )
		local bodyRows = gridContext:getItemContextListByItemType( UBFGameItemType.kBody )
		for _,bodyRow in ipairs(bodyRows) do 
			local headItemRaw = UBFFeatureHelper:getHomologousHead(boardContext, bodyRow)
			if headItemRaw and headItemRaw.itemType == bindingItemType then
				itemContext = headItemRaw
				break
			end
		end

		gridContext:release()
	end

	boardContext:release()

	return not (not itemContext)
end

function UBFShadowTargetLogic:checkWatchConfigFields( watchConfig,itemContextRaw )
	if watchConfig.watch.fieldsCheck then
		local fieldsCheck = watchConfig.watch.fieldsCheck
		for _,eachrule in ipairs(fieldsCheck) do 
            if not eachrule.field then return false end
            local value = itemContextRaw[eachrule.field]
            if eachrule.range then 
                local min = eachrule.range[1] or 0
                local max = eachrule.range[2] or 0xffff
                if value < min or value > max then return false end
            else
                if value ~= eachrule.value then return false end
            end
		end
		return true
	end
	return true
end



function UBFShadowTargetLogic:isEventOk( watchConfig,event )
	local eventName = event.eventName
	local itemContextRaw = event.itemContextRaw
	local itemType = itemContextRaw and itemContextRaw.itemType


	local eventOk = watchConfig.watch.UBFGamePlayEventEnum == eventName
	local itemTypeOk = itemType == watchConfig.watch.itemType

	local fieldsOk = self:checkWatchConfigFields( watchConfig,itemContextRaw )
	local bindingItemTypeOk = self:checkBindingItemType(watchConfig,itemContextRaw )

	-- printx(16,"eventOk",eventOk,eventName)
	-- printx(16,"itemTypeOk",itemTypeOk,itemType)
	-- printx(16,"fieldsOk",fieldsOk)
	-- printx(16,"bindingItemTypeOk",bindingItemTypeOk)
	-- printx(16,tts(watchConfig))
	-- printx(16,"----------------------")


	return eventOk and itemTypeOk and fieldsOk and bindingItemTypeOk
end


function UBFShadowTargetLogic:onGamePlayEvent( event )
	local eventName = event.eventName
	local itemContextRaw = event.itemContextRaw
	local itemType = itemContextRaw and itemContextRaw.itemType
	local watchEvents = self:getWatchEvents()
	if not watchEvents then return end


	if not watchEvents[eventName] then return end

	local shadowTargetsMap = self:getShadowTargetsMap()

	-- printx(16,"onGamePlayEvent",itemType)

	for shadowTargetType,watchDataList in pairs(shadowTargetsMap) do 
		local watchConfigs = UBFShadowTargetConfig[shadowTargetType]
		for index,watchData in ipairs(watchDataList) do 
			local watchConfig = watchConfigs[index]
			-- if itemType == UBFGameItemType.kIce then
			-- 	printx(16,"self:isEventOk(watchConfig,event)",itemType,eventName,self:isEventOk(watchConfig,event))
			-- end
			if self:isEventOk(watchConfig,event) then
				self:updateWatchData(watchData,watchConfig,event)
			end
		end
	end

end



function UBFShadowTargetLogic:updateWatchData(watchData,watchConfig,event)
	local eventName = event.eventName
	local itemContextRaw = event.itemContextRaw
	-- printx(16,itemContextRaw.level)

	-- printx(16,"===============",self:checkWatchConfigFields( watchConfig,itemContextRaw ),"self:checkWatchConfigFields( watchConfig,itemContextRaw )")
	-- if not self:checkWatchConfigFields( watchConfig,itemContextRaw ) then
	-- 	return
	-- end

	lua_switch(eventName){
		[UBFGamePlayEventEnum.kItemFieldChange] = function (  )
			local field = event.field
			if field == watchConfig.watch.eventExtend then
				self:doWatchAction(watchData,watchConfig,{
					diff = event.oldVal - itemContextRaw[field]
				})
			end
		end,
		[UBFGamePlayEventEnum.kItemDestroyed] = function (  )
			self:doWatchAction(watchData,watchConfig,{
				level = itemContextRaw.level,
			})
		end,
		[UBFGamePlayEventEnum.kBeforeAddTally] = function ( ... )
			local tallyId = event.tallyId
			if tallyId == watchConfig.watch.eventExtend then
				self:doWatchAction(watchData,watchConfig,{
					diff = event.count
				})
			end
		end,

		[UBFGamePlayEventEnum.kItemProduced] = function ( ... )
			self:doWatchAction(watchData,watchConfig,{
				level = itemContextRaw.level
			})
		end,
	}
end

local function checkCoverage( coverage,value )
	local min = coverage[1] or -10000
	local max = coverage[2] or 10000

	return value >= min and value <= max
end

local function clamp(value, a, b) return math.max(a, math.min(value, b)) end

function UBFShadowTargetLogic:ensureResultRange(watchData,range)
	local min = range[1] or -10000
	local max = range[2] or 10000

	watchData.cur = clamp(watchData.cur,min,max)
	if watchData.curMap then
		for k,v in pairs(watchData.curMap) do 
			watchData.curMap[k] = clamp(v,min,max)
		end
	end
end

function UBFShadowTargetLogic:calResultOffset(watchData,offset)
	watchData.cur = watchData.cur + offset
	if watchData.curMap then
		for k,v in pairs(watchData.curMap) do 
			watchData.curMap[k] = v + offset
		end
	end
end

function UBFShadowTargetLogic:doWatchAction( watchData,watchConfig,params )
	local action = watchConfig.action
	local coverage = action.coverage
	local resultRange = action.resultRange
	local resultOffset = action.resultOffset
	local flip = action.flip

	lua_switch(action.mode){
		[UBFShadawTargetActionMode.FIELD_DIFF] = function ( ... )
			local diff =  params.diff
			local scale =  action.scale or 1
			if coverage and (not checkCoverage(coverage,diff)) then return end
			watchData.cur = watchData.cur + diff * scale
		end,
		[UBFShadawTargetActionMode.NUM_CHANGE] = function ( ... )
			local value =  action.value
			local scale =  action.scale or 1
			watchData.cur = watchData.cur + value * scale
		end,
		[UBFShadawTargetActionMode.CUR_LEVEL] = function ( ... )
			local scale =  action.scale or 1
			if coverage and (not checkCoverage(coverage,params.level)) then return end
			watchData.cur = watchData.cur + params.level * scale
		end,
		[UBFShadawTargetActionMode.PATH_POS] = function ( ... )
			self:calBindingPath(watchData,watchConfig)
		end,
		[UBFShadawTargetActionMode.PATH_POS_TO_END] = function ( ... )
			self:calPathPosToEnd(watchData, watchConfig)
		end,
		[UBFShadawTargetActionMode.INIT_PATH_LEN] = function ( ... )
			self:calPathLength(watchData,watchConfig)
		end,
	}

	-- printx(16,flip,watchData.initNum,watchConfig.watch.itemType)
	if flip and watchData.initNum then
		watchData.flipNum  = watchData.initNum - watchData.cur
	end
	if flip and watchData.initNumMap then
		if not watchData.flipNumMap then
		 	watchData.flipNumMap = {}
		 end

		for id,cur in pairs(watchData.curMap) do
			local initNum = watchData.initNumMap[id]
			if initNum then
				watchData.flipNumMap[id] = initNum - cur
			end
		end
		-- printx(16,tts(watchData))
	end


	if resultOffset then
		self:calResultOffset(watchData,resultOffset)
	end

	if resultRange then
		self:ensureResultRange(watchData,resultRange)
	end



end


function UBFShadowTargetLogic:calGlobalShadowTarget(  )
	-- isStaticType
	local shadowTargetsMap = self:getShadowTargetsMap()
	for shadowTargetType,watchDataList in pairs(shadowTargetsMap) do 
		local watchConfigs = UBFShadowTargetConfig[shadowTargetType]
		for index,watchData in ipairs(watchDataList) do 
			local watchConfig = watchConfigs[index]
			-- printx(16, not self:isStaticType(watchConfig.watch.type),"------------------------")
			if not self:isStaticType(watchConfig.watch.type) then
				-- self:updateWatchData(watchData,watchConfig,event)
				self:calWatchData(watchData,watchConfig)
			end
		end
	end
end

function UBFShadowTargetLogic:doWatchInit( )

	local initByCur = function ( watchData )
		local curMap = watchData.curMap
		local initNumMap = {}

		for id,cur in pairs(curMap) do
			initNumMap[id] = cur
		end
		watchData.initNumMap = initNumMap
		watchData.initNum = watchData.cur
	end


	local shadowTargetsMap = self:getShadowTargetsMap()
	for shadowTargetType,watchDataList in pairs(shadowTargetsMap) do 
		local watchConfigs = UBFShadowTargetConfig[shadowTargetType]
		for index,watchData in ipairs(watchDataList) do 
			local watchConfig = watchConfigs[index]
			-- printx(16,watchConfig.watch.recordInit,"watchConfig.watch.recordInit")
			if watchConfig.watch.recordInit then
				self:doWatchAction(watchData,watchConfig)
				initByCur(watchData)
			end
		end
	end

end


function UBFShadowTargetLogic:reInitWatch(  )
	local reInitByCur = function ( watchData )
		local curMap = watchData.curMap

		for id,cur in pairs(curMap) do
			if not watchData.initNumMap[id] then
				watchData.initNumMap[id] = cur
			end
		end
	end


	local shadowTargetsMap = self:getShadowTargetsMap()
	for shadowTargetType,watchDataList in pairs(shadowTargetsMap) do 
		local watchConfigs = UBFShadowTargetConfig[shadowTargetType]
		for index,watchData in ipairs(watchDataList) do 
			local watchConfig = watchConfigs[index]
			-- printx(16,watchConfig.watch.recordInit,"watchConfig.watch.recordInit")
			if watchConfig.watch.recordInit then
				self:doWatchAction(watchData,watchConfig)
				-- printx(16,tts(watchData))
				reInitByCur(watchData)
				-- printx(16,tts(watchData))
			end
		end
	end

end

local function convert2fieldCond( fieldsCheck )
	-- body
	local fieldCond = {}
	for _,rule in ipairs(fieldsCheck) do
		if rule.value then
			table.insert(fieldCond,{
            	 val = rule.value , 
            	 field = rule.field , 
            	 mode = UBFBoardFilterConst.kValue,
			})	
		elseif rule.range then
			table.insert(fieldCond,{ 
				min = rule.range[1], 
				max = rule.range[2] , 
				field = rule.field , 
				mode = UBFBoardFilterConst.kRange ,
			})
		end
	end
	return fieldCond
end


function UBFShadowTargetLogic:calWatchData( watchData,watchConfig )
	local boardContext = self.levelContext:getBoardContext(self.boardId)
	
	local watch = watchConfig.watch

	lua_switch(watch.type){
		[UBFShadowTargetStatisticType.kCalculateViewVoard] = function ( ... )
			local itemType = watchConfig.watch.itemType
			local filter = {
		        isGlobal = true,
		        itemType = itemType, 
		        fieldCond = convert2fieldCond(watchConfig.watch.fieldsCheck)
		    }
		    local itemRawList = boardContext:filter(filter)
		    watchData.cur = #itemRawList
		end,
		[UBFShadowTargetStatisticType.kBandingPath] = function ( ... )
			-- self:calBindingPath(watchData,watchConfig)
			self:doWatchAction(watchData,watchConfig)
		end,
		[UBFShadowTargetStatisticType.kPathPosToEnd] = function ( ... )
			-- self:calPathPosToEnd(watchData, watchConfig)
			self:doWatchAction(watchData,watchConfig)
		end,
		[UBFShadowTargetStatisticType.kPathLength] = function ( ... )
			self:doWatchAction(watchData,watchConfig)
			-- self:calPathLength(watchData,watchConfig)
		end
	}
	boardContext:release()
end

function UBFShadowTargetLogic:calBindingPath( watchData,watchConfig )
	local boardContext = self.levelContext:getBoardContext(self.boardId)

	local itemType = watchConfig.watch.itemType
	local bindingPathItemType = watchConfig.watch.bindingPathItemType
    local baseItemRaws = boardContext:filter({
        isGlobal = true,
        itemType = itemType, 
    })	
	for _,itemRaw in ipairs(baseItemRaws) do 
		local pos = itemRaw.pos
		local id = itemRaw.id
   		local cur = self:getPathPos(pos,bindingPathItemType)
   		watchData.curMap[id] = cur
    end

	boardContext:release()
end

-- 当前距离路径终点的剩余距离
function UBFShadowTargetLogic:calPathPosToEnd(watchData, watchConfig)
	local boardContext = self.levelContext:getBoardContext(self.boardId)

	local itemType = watchConfig.watch.itemType
	local bindingPathItemType = watchConfig.watch.bindingPathItemType
    local baseItemRaws = boardContext:filter({
        isGlobal = true,
        itemType = itemType, 
    })	
	for _, itemRaw in ipairs(baseItemRaws) do 
		local pos = itemRaw.pos
		local id = itemRaw.id
   		local cur = self:getPathPosToEnd(pos, bindingPathItemType)
   		watchData.curMap[id] = cur
    end

	boardContext:release()
end

function UBFShadowTargetLogic:calPathLength( watchData,watchConfig )
	local boardContext = self.levelContext:getBoardContext(self.boardId)

	local itemType = watchConfig.watch.itemType
    local baseItemRaws = boardContext:filter({
        isGlobal = true,
        itemType = itemType, 
    })
    local visited = {}
	for _,itemRaw in ipairs(baseItemRaws) do 
        local startItemRow =  UBFFeatureHelper:getRouteStartItemContextRaw(boardContext, itemRaw)
        if not visited[startItemRow.id] then
        	-- printx(16,tts(startItemRow.route))
        	local currLength = startItemRow.route.routeRef.currLength
        	local initLength = startItemRow.route.routeRef.initLength

        	visited[startItemRow.id] = true
        	watchData.curMap[startItemRow.id] = (initLength - currLength)
        end
    end
	boardContext:release()
end
















