_G.UBF_NO_REQUIRE_LUA_FLAG()

-- ! 核心引用放到UBFCommonRquireMap统一管理，为后面切线程做准备

UBFGameBoardModuleEnum = {
    kJudge = "judge",
    kTreeLauncher = "tlnchr"
}

UBFGameBoardLogic =  class2( "UBFGameBoardLogic" , UBFBaseLogic )

function UBFGameBoardLogic:init( createData )

    self.contextManager = UBFContextManager:getInstance()
    self.conditionManager = UBFConditionManager:getInstance()

    self.messageManager = createData.messageLogic
    self.threadId = createData.threadId

	self.hrc = UBFLuaHelper:hrc()
	self.ophrc = UBFLuaHelper:hrc()

    --
--


    UBFBaseLogic.init( self , createData  )
end

function UBFGameBoardLogic:build(createData)
    UBFGameLaunchHook:dispatch(UBFGameLaunchHook.kGameBoardLogicBuildStart, self, createData)
    self.levelContext = self.contextManager:getValue({ UBFConst.ContextType.kLevelContext }):hold()

    self.swapProposeListCache = nil --棋盘稳定时可交换列表数组
    self.swapProposeListCacheForView = nil --棋盘稳定时可交换列表数组，专门给视图的

    self:buildLogicActionManager()
    self:buildListeners()
    self:buildStateMachine()
    self:buildMatchLogic()
    self:buildSwapLogic()
    self:buildFallingLogic()
    self:buildProductLogic()
    self:buildLeagueLogic()
    self:buildGameJudgeLogic()
    self:buildBTreeLaunchLogic()
    self:buildSnapshotLogic()
    self:buildFuuuLogic()
    self:buildShadowTargetLogic()
    -- self:buildDiffChangeLogic()
    -- self:buildDiffChangeLogicAgent()
    self:buildBoardInitAdjustLogic()

    if createData.bySwitchGame and createData.gameOperationLogic then 
        createData.gameOperationLogic:move({ gameBoardLogic = self })
        self.operationLogicId = self:addAgented(createData.gameOperationLogic)
    else
        self:buildOperationLogic() --! 只有该类能负责replay，其他的逻辑应该都是replay无关的！
    end
    -- self:buildRandomFactory() -- 使用 boardContext:nextSeed( channelKey? : string )

    UBFGameLaunchHook:dispatch(UBFGameLaunchHook.kGameBoardLogicBuildEnd, self)
end

function UBFGameBoardLogic:moveLogic(logicId)
    local logic = self:getAgentedById(logicId)
    self:removeAgentedById(logicId)
    return logic
end

function UBFGameBoardLogic:buildListeners()
    self:registerListener(UBFPlayEventType.kPushOperation, self.onPushOperation, self, UBFEventListenerLevel.kOriginAndBubbleFloat)
end

function UBFGameBoardLogic:buildStateMachine()
    self.stateMachineIdMap = {}
    self:buildStateMachineByBoardId(1)
end

function UBFGameBoardLogic:buildStateMachineByBoardId(boardId)
    if self.stateMachineIdMap[boardId]  then UBFThrow "重复的状态机" end
    local createdata = UBFBoardStateMachine:getDefaultCreateData()
    createdata.gameboardlogic = self
    createdata.boardId = boardId
    self.stateMachineIdMap[boardId] = self:addAgented(UBFBoardStateMachine:create(createdata))
end

function UBFGameBoardLogic:removeAllStateMachine()
    for boardId, id in pairs(self.stateMachineIdMap) do 
        self:removeAgentedById(id)
    end
    self.stateMachineIdMap = {}
end

function UBFGameBoardLogic:buildMatchLogic()
    require "ubf.UBFPlay.logics.matchmix.UBFMatchItemLogic"
    self.matchItemLogicId = self:addAgented(UBFMatchItemLogic:create({ 
        gameBoardLogic = self,
    }))
end

function UBFGameBoardLogic:buildSwapLogic()
    require "ubf.UBFPlay.logics.swap.UBFSwapLogic"
    local swapLogic = UBFSwapLogic:create { 
        matchItemLogic = self:getAgentedById(self.matchItemLogicId),
        gameBoardLogic = self
    }
    self.swapLogicId = self:addAgented(swapLogic)
end

function UBFGameBoardLogic:buildFallingLogic()
    
    -- if true or self.levelContext:getGameGroupTestValue( "falling_sptest" ) then

    require "ubf.UBFPlay.logics.falling.UBFFallingItemLogicV2_1"

    self.fallingItemLogicId = self:addAgented( UBFFallingItemLogicV2_1:create({ 
        gameBoardLogic = self , --掉落算法开销大，直接引用
    }) )

    -- else
    --     require "ubf.UBFPlay.logics.falling.UBFFallingItemLogic"

    --     self.fallingItemLogicId = self:addAgented( UBFFallingItemLogic:create({ 
    --         gameBoardLogic = self , --掉落算法开销大，直接引用
    --     }) )
    -- end
end

function UBFGameBoardLogic:buildBoardInitAdjustLogic()
    require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFBoardInitAdjustLogic"
    self.boardInitAdjustLogicId = self:addAgented( UBFBoardInitAdjustLogic:create({ 
        gameBoardLogic = self ,
    }) )
end

--[[
function UBFGameBoardLogic:buildDiffChangeLogicAgent()
    -- printx( 1 , "UBFGameBoardLogic:buildDiffChangeLogic ++++++++++++++++++" )

    require "ubf.UBFPlay.logics.product.UBFProductItemDiffChangeAgent"
    self.levelDiffChangeLogicId = self:addAgented( UBFProductItemDiffChangeAgent:create({ 
        gameBoardLogic = self ,
    }) )
end
]]

function UBFGameBoardLogic:buildProductLogic()
    require "ubf.UBFPlay.logics.product.UBFProductItemLogic"
    self.productItemLogicId = self:addAgented( UBFProductItemLogic:create({ 
        gameBoardLogic = self
    }) )
end

function UBFGameBoardLogic:buildLeagueLogic()
    require "ubf.UBFPlay.logics.UBFGameLeagueLogic"
    self.leagueLogicId = self:addAgented( UBFGameLeagueLogic:create({  gameBoardLogic = self }) )
end

function UBFGameBoardLogic:buildOperationLogic()
    require "ubf.UBFPlay.logics.UBFGameOperationLogic"
    self.operationLogicId = self:addAgented(UBFGameOperationLogic:create({ 
        gameBoardLogic = self,
    }))
end

function UBFGameBoardLogic:buildGameJudgeLogic( createData )
    require "ubf.UBFPlay.logics.judge.UBFGameJudgeLogic"
    self.judgeLogicId = self:addAgented(UBFGameJudgeLogic:create({ 
        gameBoardLogic = self,
    }))
end

function UBFGameBoardLogic:buildBTreeLaunchLogic( createData )
    require "ubf.UBFPlay.logics.dispatch.UBFGameBTreeLaunchLogic"
    self.btLaunchLogicId = self:addAgented(UBFGameBTreeLaunchLogic:create({ 
        gameBoardLogic = self,
    }))
end

function UBFGameBoardLogic:buildSnapshotLogic( createData )
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

function UBFGameBoardLogic:buildFuuuLogic( createData )
    self.fuuuGraphLogicId = self:addAgented(UBFFuuuGraphLogic:create({ 
        gameBoardLogic = self,
    }))
end

function UBFGameBoardLogic:buildShadowTargetLogic( createdata )
    self.shadowTargetLogicId = self:addAgented(UBFShadowTargetLogic:create{
        gameBoardLogic = self,
    })    
end


function UBFGameBoardLogic:buildDiffChangeLogic()
    -- printx( 1 , "UBFGameBoardLogic:buildDiffChangeLogic ++++++++++++++++++" )

    -- local _gameEnv = self.levelContext:getGameEnv()
    local _UBFuuuAdjustModEnv = self.levelContext:getModSourceEnv( tostring(UBFModSourceIdEnum.kDiffAdjustModMgr) )

    --
--


    if _UBFuuuAdjustModEnv and _UBFuuuAdjustModEnv.enableUBFuuu then
        require "ubf.UBFPlay.logics.product.UBFProductItemDiffChangeLogicV2"
        self.levelDiffChangeLogicId = self:addAgented( UBFProductItemDiffChangeLogicV2:create({ 
            gameBoardLogic = self ,
            adjustModEnv = _UBFuuuAdjustModEnv
        }) )
    end
    
end


-- function UBFGameBoardLogic:buildRandomFactory()
    
-- end

function UBFGameBoardLogic:buildLogicActionManager()
    require "ubf.UBFPlay.logics.logicActions.UBFLogicActionManager"
    require "ubf.UBFPlay.logics.logicActions.configs.UBFLogicActionData"
    self.logicActionManagerId = self:addAgented( UBFLogicActionManager:create( { gameBoardLogic = self } ) )
end

function UBFGameBoardLogic:dispose()
    if self.isDisposed then return end
	self.isDisposed = true

    if self.hrc then 
        self.hrc:close()
        self.hrc = nil
    end

    if self.ophrc then 
        self.ophrc:close()
        self.ophrc = nil
    end

    self:stopMainLoop()

    --
--

end

function UBFGameBoardLogic:onGameCrash( err )
    self:stopMainLoop()
end

--------------------****** *↓* ******--------------------
--				       棋盘启动与构建
--------------------****** *↑* ******--------------------

--游戏启动调用，无论是否断面回复，都调用，表明逻辑开始运行
function UBFGameBoardLogic:startLevel( startLevelData )
    printx( 1 , "UBFGameBoardLogic:startLevel  ~~~~~~~~~~~~~~~~~~~~~ "  )

    --fps 线程最外面调整
    self:startMainLoop()
    local runnableOrderList = self:getRunnableBoardIdList()
    for _, boardId in ipairs(runnableOrderList) do 
        self:callById(self.stateMachineIdMap[boardId], "run")
    end

    -- 发送期盼构建信息给视图，迁移到了UBFPMLaunch中
    -- self.messageManager:sendMessages( self:createGameBoardViewBuildInitMessage( 1 ) )

    --不发了，直接视图根据关卡配置自己初始化了
    -- local targetMap = self:callById( self.leagueLogicId , "getTargetMap" , 1 )
    -- self:sendUIAction( UBFUIActionType.kInitUI , {
    --     targets = UBFHelper:toList( targetMap , function( v , k ) 
    --         return {
    --             tallyId = k,
    --             count = v.expect
    --         } 
    --     end),
    --     scoreTargets = self:callById( self.leagueLogicId , "getScoreTargets" , 1 ) ,
    -- } )
    -- self:sendUIAction( UBFUIActionType.kTallyChange , {
    --     isInit = true,
    --     tallyId = UBFTallyId.kMoveStep,
    --     tallyKind = UBFTallyKind.kCustom,
    --     count = self:callById( self.leagueLogicId , "getRestMoveCount" , 1 ) 
    -- } )
    --通知snapshot
    pcall(function() self:callById(self.snapshotLogicId, "catchStep") end)
end

--棋盘正常启动初始化时调用，断面恢复时不调用
--断面回复数据直接注入了，简单的理解是支持反序列成为了棋盘的最终状态，所以预期上不需要任何初始化
--这个函数为回放环境数据无关的初始化，即仅根据levelConfig来生成内容，不依赖其它动态数据。只要levelconfig和种子一致，该函数的运行结果应当是一致的
--像本关携带的活动buff，前置道具之类的，并不是这个函数初始化，而是被推入init的操作，并调用 gameStartInit
function UBFGameBoardLogic:gameBoardInit( createData )

    local boardContextMap = {}
    for id , boardContextRaw in pairs(self.levelContext:getBoardRawDataMap()) do 
        boardContextMap[id] = UBFContextManager:pack(boardContextRaw)
    end
    local boardContext = boardContextMap[1]

    --
--


    --基础全局初始化
    self:callById(self.leagueLogicId, "gameInit", createData)
    self:callById(self.judgeLogicId, "gameInit", createData)
    self:callById(self.productItemLogicId, "initBoard", boardContext)
    self:callById(self.btLaunchLogicId, "gameInit", createData)
    
    --初始化Env数据
    local startInitData = createData.startInitData or {}
    local initData = {}
    local modList = {}
    initData.modList = modList
    local function loadMod( list )
        for k , modData in ipairs(list) do
            local sourceId = modData.sourceId
            if not sourceId then UBFThrow("找不到mod的SourceID" .. tostring(modData.mType) ) end
            --注入换进变量
            if modData.env then 
                local gEnv = self.levelContext:getValue(UBFLevelContext.gameEnvKey)
                gEnv.modSrcEnv[sourceId] = modData.env
            end
            table.insert(modList, { 
                mType = modData.mType,
                sourceId = sourceId, 
                buildData = modData.buildData,
            })
        end
    end
    if startInitData.buffList then loadMod(startInitData.buffList ) end
    if startInitData.modList then loadMod(startInitData.modList ) end
    if startInitData.fuuuGraph then initData.fGraph = startInitData.fuuuGraph end
    UBFGamePlayTest:recordUploadCosBoardInitInput(self.levelContext, createData, initData)

    local itemActions = require "ubf.UBFPlay.logics.logicActions.ItemInitAction"
    local fallingSeed = boardContext:nextSeed("falling")
    local itemTypeMap, itemColorMap = {} , {}
    
    --最开始的生成规则，优先级最高，下面获取feature也要根据这个
    for boardId, singleBoardContext in pairs(boardContextMap) do 
        if singleBoardContext._rawData.itemGenRules then
            itemActions:initBoardGenItems(self, singleBoardContext, singleBoardContext._rawData.itemGenRules)
            singleBoardContext._rawData.itemGenRules = nil
        end
    end

    local runnableOrderList = {}
    for boardId, singleBoardContext in pairs(boardContextMap) do 
        --获取游戏中所有会用到的featureMap
        local currItemTypeMap, currItemColorMap = UBFBoardItemHelper:getGameUsedItemTypeMap(self, singleBoardContext)
        for k , v in pairs(currItemTypeMap) do 
            if not itemTypeMap[k] then itemTypeMap[k] = v 
            else UBFHelper:deepMerge(itemTypeMap[k], v) end
        end
        for k , v in pairs(currItemColorMap) do 
            itemColorMap[k] = true
        end
        --基础初始化
        if not singleBoardContext:isMainBoard() then 
            if singleBoardContext:isMultiBoardRunnable() then
                self:buildStateMachineByBoardId(boardId)
                table.insert(runnableOrderList, boardId)
            end
        else
            table.insert(runnableOrderList, boardId)
        end 
    end

    table.sort(runnableOrderList, function(a, b) return a < b end)
    self.levelContext:setMutilBoardOrderList("runnable", runnableOrderList)
    if #runnableOrderList > 1 then 
        self.levelContext:setValue("flagMutilRun", true) 
        UBFMultiBoardHelper:refreshMultiBoardHelpMap(self.levelContext)
    end

    itemTypeMap[UBFGameItemType.kFirecracker] = {}

    --处理featureMap
    local featureMap = {}
    for itemType, v in pairs(itemTypeMap) do 
        local data = v
        if type(v) ~= "table" then data = {} end
        featureMap[itemType] = v
    end

    self.levelContext:setValue("featureMap", featureMap)
    createData.featureMap = featureMap

    --初始化同源障碍
    for _ , singleBoardContext in pairs(boardContextMap) do 
        self:_initHeadBody(singleBoardContext)
        self:_initRouteConfigData(singleBoardContext)
    end

    -- 游戏使用颜色初始化
    self:randomBoardColorUse(boardContext)
    for _ , singleBoardContext in pairs(boardContextMap) do 
        if singleBoardContext ~= boardContext then
            singleBoardContext:setValue("boardColor", boardContext:getValue("boardColor"))
        end
    end
    
    --更新使用颜色列表
    local colors = boardContext:getUseColors()
    for _, color in ipairs(colors) do
        itemColorMap[color] = true
    end

    --根据障碍静态配置的feature，初始化静态配置
    for itemType, data in pairs(featureMap) do 
        local features = UBFGameItemStaticConfig[itemType].features or {}
        itemActions:prevInitByFeatures(self, boardContextMap, itemType, features)
    end

    local importantSiteMap = self.levelContext:getValue("importantSiteMap")
    for _ , list in pairs(importantSiteMap) do 
        table.sort(list, function(a, b) return (a.priority or 0) > (b.priority or 0) end)
    end

    --todo BAD START 随机初始化大眼仔 禁止在这里继续加了，之后的全加到features的initRules里面

    -- if featureMap[UBFGameItemType.kHaystack] then
    --     itemActions:initRandomHaystack(boardContextMap, boardContext)
    -- end

    -- if featureMap[UBFGameItemType.kCanevine] then
    --     itemActions:initCanevine(boardContext)
    -- end

    -- if featureMap[UBFGameItemType.kColorRobot] then
    --     itemActions:initRandomColorRobot(boardContext)
    -- end

    -- todo END　START ~~~~~~ 禁止在这里继续加了，之后的全加到features的initRules里面
    self:callById(self.boardInitAdjustLogicId , "beforeBoardColorInit", boardContext)
    
    --随机颜色
    for _ , singleBoardContext in pairs(boardContextMap) do 
        self:randomColorMap(singleBoardContext)
    end

    self:callById(self.productItemLogicId, "statisticsItemCountInBoard")

    for _, boardId in pairs(runnableOrderList) do 
        self:callById(self.productItemLogicId, "refreshRules", boardContextMap[boardId], UBFProduceTriggerEvent.kInit)
    end

    self.levelContext:createNewStepContext(0)
    
    --障碍构建

    --todo 禁止在这里继续加了，之后的全加到features的initRules里面
    if featureMap[UBFGameItemType.kCupboard] then 
        itemActions:initCupboardDogIndex(boardContext) 
    end 
    if featureMap[UBFGameItemType.kChocolate] then
        itemActions:initChocolateValidBodyItemIds(boardContextMap) 
    end
    -- todo END　~~~~~~ 禁止在这里继续加了，之后的全加到features的initRules里面

    --根据障碍静态配置的feature，初始化静态配置
    local initOrderList = {}
    for itemType, data in pairs(featureMap) do 
        local features = UBFGameItemStaticConfig[itemType].features or {}
        table.insert(initOrderList, { itemType = itemType, features = features, order = features.initOrder or 0 })
    end
    table.sort(initOrderList, function(a, b) return a.order < b.order end)
    local extra = {
        bySwitchGame = createData.bySwitchGame,
		switchUUID = createData.switchUUID,
    }
    for _, data in ipairs(initOrderList) do  
        itemActions:initByFeatures(self, boardContextMap, data.itemType, data.features, extra)
    end

    itemActions:initByGlobal(self, boardContextMap, UBFGameGlobalConfig)
    itemActions:initAboutRefresh(self, boardContextMap)

    for _ , singleBoardContext in pairs(boardContextMap) do 
        --初始化每个棋盘的掉落算法的随机缓存信息（根据四个重力方向综合计算计算），
        --不过其他棋盘(>1)并不会掉落
        --注意，顺序敏感。尤其其它障碍可能会改变Grid的重力方向，所以 updateFallingOrderRandomList 的调用需要在障碍初始化之后
        self:callById(self.fallingItemLogicId, "updateFallingOrderRandomList", singleBoardContext, fallingSeed)
    end

    --其他都ok了，最后初始化fuuu
    self:callById(self.shadowTargetLogicId , "gameInit" , createData)
    self:callById(self.fuuuGraphLogicId , "gameInit" , createData)


    for _ , boardContext in pairs(boardContextMap) do 
        boardContext:release()
    end

    --附属模块构建
    local moduleLogicIdMap = {
        [UBFGameBoardModuleEnum.kJudge] = self.judgeLogicId,
        [UBFGameBoardModuleEnum.kTreeLauncher] = self.btLaunchLogicId,
    }
    -- appendModules 的格式详见关卡编辑器 RawLevelData.ts -> interface UBFRawGameModule
    local appendModules = createData.levelConfig.appendModules or {}
    for k , v in ipairs( appendModules ) do 
        local logicId = moduleLogicIdMap[v.targetKey]
        if logicId then self:callById( logicId , "addGameModule" , boardContext , v ) end
    end

    self:pushOperation(UBFOperationType.kInit, initData)

    -- 构建难度调整执行模块，注意，它需要在mod初始化完毕后构建
    self:buildDiffChangeLogic() 
end

function UBFGameBoardLogic:onGameSwitchFinish(createData)
    self:markTakeSection(UBFSectionType.kFast, true)

    --发送切换游戏指定
    self.messageManager:sendMessages({
        mType = UBFGameMessageType.kShiftGame,
        toUUID = createData.switchUUID,
        extraData = createData.extraData
    })
    
	local dat = self:createGameBoardViewBuildInitMessage(1, false)
	dat.byLaunch = true
    self.messageManager:sendMessages(dat)

    --发送ui变化
    local targetMap = self:callById(self.leagueLogicId, "getTargetMap")

    local inheritCurrVal = false
    local switchConfig = createData.switchConfig
    if switchConfig then
        if switchConfig.shouldInheritLeagueContext then
            inheritCurrVal = true
        end
    end

    self:sendUIAction( UBFUIActionType.kInitUI , {
        targets = UBFHelper:toList(targetMap, function(v, k) 
            return {
                tallyId = k,
                count = v.expect,
                currVal = inheritCurrVal and v.currVal
            }
        end),
        moveCount = self:leagueCall("getRestMoveCount"),
        scoreTargets = self:callById(self.leagueLogicId, "getScoreTargets"),
    })
end

function UBFGameBoardLogic:randomColorMap( boardContext )
    local boardMap = boardContext:getBoardMap()

    local boardSize =  boardContext:getValue("boardSize")
    local boardBorder = boardContext:getValue( "boardBorder" )

    local allBorder = {
        left = 1,
        right = boardSize.width,
        top = 1,
        bottom = boardSize.height,
    }
    
    local seed = boardContext:nextSeed()

    -- if UBF_USE_NEW_REFRESH_LOGIC then 
    -- test
    -- for i = 1 , 1000 do
    --     local refreshLogic = UBFRandomColorHelper:createRefreshLogic()
    --         :setPassBlockEffect( true )
    --         :setAllMoveLock( true )
    --     refreshLogic:loadGirdMap( boardContext , allBorder )
    --     refreshLogic:ensureOneMatchSwap( boardContext:nextSeed("test") , boardBorder )
    --     if refreshLogic:checkHasContinuity() then 
    --         printx(21, "99 shit!" , boardContext:getBoardSeed() )
    --     end
    -- end
    local refreshLogic 
    
    --新的随机算法在小牌面下有一定的概率会随机到三连的情况，但是新算法的效率很高
    --所以重复执行，让随机到三连个概率趋近于0
    for i = 1, 4 do 
        refreshLogic = UBFRandomColorHelper:createRefreshLogic()
            :setPassBlockEffect(true)
            :setAllMoveLock(true)
            :setOccasion(UBFCalcColorOccasion.kInit)
        refreshLogic:loadGirdMap(boardContext, allBorder)
        refreshLogic:ensureOneMatchSwap(seed, boardBorder)
        local hasBad = refreshLogic:ensureNoContinuity(seed)
        if not hasBad then break end
        seed = UBFRandom:nextSeed(seed)
    end
    
    -- refreshLogic:printMap(21)
    --更新
    refreshLogic:travelMap(function(r, c, piece)
        local gridContext = UBFContextManager:pack(boardMap[r][c])
        local item = gridContext:getItemMasterRawData()
        item.color = piece.color
        boardContext:indexUpdateFieldChange( item )
        gridContext:release()
    end)
end

function UBFGameBoardLogic:randomBoardColorUse( boardContext )
    local seed = boardContext:nextSeed()
    local boardColor = boardContext:getValue("boardColor")

    local weightColor = boardColor.weightColor

    local minUseWeight = nil
    for _, w in pairs(weightColor) do 
        if w > 0 then 
            if not minUseWeight then minUseWeight = w 
            else minUseWeight = math.min(minUseWeight, w) end
        end
    end

    local forbiddenColorMap = {}    --禁用颜色的map

    local mustColorMap = {}
    local mustColorList = {}        --必须选择的color队列，及第一优先级
    local fallbackColorList = {}    --保底的颜色队列，及最后优先级

    for colorIndex = 1 , 6 do 
        if weightColor[colorIndex] == -1 then 
            weightColor[colorIndex] = 1
            forbiddenColorMap[colorIndex] = true
        elseif not weightColor[colorIndex] or weightColor[colorIndex] == 0 then 
            weightColor[colorIndex] = minUseWeight or 1
            table.insert(fallbackColorList, colorIndex) 
        elseif weightColor[colorIndex] > 0 then
            table.insert(mustColorList, colorIndex) 
            mustColorMap[colorIndex] = true
        end
    end

    --如果是全色的，直接走人了
    if boardColor.colorCount >= 6 then 
        boardColor.useColors = { 1 , 2 , 3 , 4 , 5 , 6 }
        return
    end
    
    local colorSelectPriorityList = {}

    local function addColorList( colors , priority , order )
        if not colors or #colors == 0 then return end
        table.insert( colorSelectPriorityList , { 
            colors = colors , 
            priority = priority ,
            order = order,
        } )
    end

    --直接配的，最优先
    addColorList(mustColorList, 100) 
    --没配的，兜底的
    addColorList(fallbackColorList, 0) 
    -- --收集目标的颜色
    -- local tallyColors = self:_findGameTargetColorList( boardContext ) 
    -- local tallyColorMap = {}
    -- for _ , color in ipairs(tallyColors) do tallyColorMap[color] = true end
    --棋盘上的颜色
    local boardColors = self:_findBoardExistColorList( boardContext ) 
    -- local boardColorsInTally = {}
    -- local boardColorsOutTally = {}
    -- for _  , color in ipairs(boardColors) do 
    --     if tallyColorMap[color] then table.insert(boardColorsInTally, color)
    --     else table.insert(boardColorsOutTally, color) end
    -- end
    -- --优先存在目标的颜色
    -- addColorList(boardColorsOutTally , 80 ) 
    -- addColorList(boardColorsInTally , 90 ) 
    addColorList(boardColors, 80, true)

    --创建最高优先级表
    local godColorList = {}
    for _, color in pairs(boardColors or {}) do 
        if mustColorMap[color] then 
            table.insert(godColorList, color)
        end
    end
    if #godColorList > 0 then addColorList(godColorList, 200) end

    --进行选择
    
    local function doSelectColor()
        table.sort( colorSelectPriorityList , function( a , b ) return a.priority > b.priority end)
        
        local useColors = {}
        local useColorMap = {}

        local function addColor( color )
            if forbiddenColorMap[color] then return end
            if not useColorMap[color] then 
                useColorMap[color] = true
                table.insert( useColors , color )
                return #useColors >= boardColor.colorCount
            end
        end

        for k , colorData in ipairs( colorSelectPriorityList ) do 
            local colors = colorData.colors
            if colorData.order then 
                -- 顺序模式
                for k , color in ipairs( colors ) do 
                    if addColor( color ) then return useColors end -- 颜色选择齐了
                end
            else
                --随机模式
                while #colors > 0 do 
                    seed = UBFRandom:nextSeed( seed , 955481 )
                    local index = UBFRandom:calcValue( seed , 1 , #colors )
                    local color = table.remove( colors , index ) 
                    if addColor( color ) then return useColors end -- 颜色选择齐了
                end
            end
        end

        return useColors
    end

    boardColor.useColors = doSelectColor()
    
    --如果颜色不足要求，证明forbidden多了！
    if #boardColor.useColors < boardColor.colorCount then 
        -- 怎么说，补不补？
        -- for color , _ in pairs( forbiddenColorMap ) do 
        --     table.insert( boardColor.useColors , color )
        --     if #boardColor.useColors >= boardColor.colorCount then break end
        -- end
    end
    
    table.sort(boardColor.useColors, function(a, b) return a < b end)
end

function UBFGameBoardLogic:_initHeadBody(boardContext)
    local colorMap = {}
    local posMap = boardContext:getGridPosMap()

    local boardSize = boardContext:getValue("boardSize")

    local allBorder = {
        left = 1,
        right = boardSize.width,
        top = 1,
        bottom = boardSize.height,
    }

    for r = allBorder.top, allBorder.bottom do
        for c = allBorder.left, allBorder.right do
            local posKey = r * MACRO_POS_STRIDE + c
            local gridRawContext = posMap[posKey]
            local itemRawTypeMap = gridRawContext and gridRawContext[UBFGridContext.itemTypeMapKey] or nil
            local boardItemRawList = itemRawTypeMap and itemRawTypeMap[UBFGameItemType.kBody] or {}
            self:_initHeadBodyItemList(boardContext, boardItemRawList)
        end
    end

end

function UBFGameBoardLogic:_initHeadBodyItemList(boardContext, boardItemRawList)
    local posMap = boardContext:getGridPosMap()
    local changeLayerList = {}
    for index, bodyItemRaw in ipairs(boardItemRawList) do
        -- 这里不再处理已初始化完成的
        if not bodyItemRaw.headId or bodyItemRaw.headId == 0 then 
            local headR, headC = bodyItemRaw.headPos.r, bodyItemRaw.headPos.c
            -- printx(15,"headR, headC",headR, headC, bodyItemRaw.id)
            local headItemType = bodyItemRaw.headItemType
            local headPosKey = headR * MACRO_POS_STRIDE + headC
            local headBoardItemRawList = posMap[headPosKey][UBFGridContext.itemTypeMapKey][headItemType]
            local headItemRaw = headBoardItemRawList[1]
            -- 多个同itemType的head在同一格的情况，那一个没有被初始化的
            if #headBoardItemRawList > 0 then 
                for _ , _headItemRaw in ipairs(headBoardItemRawList) do 
                    if #_headItemRaw.bodyIdList == 0 then
                        headItemRaw =  _headItemRaw
                        break
                    end
                end
            end
            bodyItemRaw.headId = headItemRaw.id
            table.insert(headItemRaw.bodyIdList, bodyItemRaw.id)
            if bodyItemRaw.logicLayer ~= headItemRaw.logicLayer then 
                table.insert(changeLayerList, {
                    head = headItemRaw, 
                    body = bodyItemRaw
                })
            end
        end
    end
    --更新层级
    for _ , v in ipairs(changeLayerList) do 
        local pos = v.body.pos
        local gridContext = UBFContextManager:pack(posMap[pos.r * MACRO_POS_STRIDE + pos.c])
        gridContext:removeItemContext(v.body, true)
        v.body.logicLayer = v.head.logicLayer
        v.body.currAttackOrder = v.head.currAttackOrder
        v.body.forbidAttackPass = v.head.forbidAttackPass
        if v.body.logicLayer ~= UBFItemLogicLayerType.kItem then
            UBFItemContext:rawCall(v.body, "_removeTag", UBFGameItemTag.kMasterClass)
        end
        v.body.blockFalling = v.head.blockFalling
        v.body.blockSwap = v.head.blockSwap
        v.body.blockMatch = v.head.blockMatch
        v.body.blockAttack = v.head.blockAttack
        v.body.blockEffect = v.head.blockEffect
        v.body.blockBorderAttackMap = UBFHelper:deepClone(v.head.blockBorderAttackMap)
        gridContext:addItemContext(v.body, false)
        gridContext:release()
    end
end

--初始化路径数据
function UBFGameBoardLogic:_initRouteConfigData(boardContext)
    local posMap = boardContext:getGridPosMap()
    local boardSize =  boardContext:getValue("boardSize")

    local allBorder = {
        left = 1, right = boardSize.width,
        top = 1, bottom = boardSize.height,
    }

    for r = allBorder.top , allBorder.bottom do
        for c = allBorder.left , allBorder.right do
            local posKey = r * MACRO_POS_STRIDE + c
            local gridRawContext = posMap[posKey]
            local itemRawList = gridRawContext and gridRawContext[UBFGridContext.itemListKey] or {}
            self:_initRouteConfigDataByItemList(boardContext, itemRawList)
        end
    end
end

function UBFGameBoardLogic:_initRouteConfigDataByItemList(boardContext, itemRawList)
    local posMap = boardContext:getGridPosMap()
    local routeMap = boardContext:getValue("routeMap")
    local routeList = boardContext:getValue("routeList")

    local newRouteItemList = {}
    local startRouteItemList = {}

    for i, v in ipairs(itemRawList) do
        local routeData = v.route
        if routeData and (routeData.isStart or routeData.coords) then
            table.insert(startRouteItemList, v)
        end
    end

    local routeCheckMap = {}

    --遍历所有开始路径节点
    for k, startRouteItemRaw in ipairs(startRouteItemList) do
        local startRoute = startRouteItemRaw.route

        --有routeId的说明已经初始化过了
        if not startRoute.routeId then

            local routeId = self.levelContext:genNextId()

            routeMap[routeId] = {
                isLoop = false,                         --路径是否循环
                itemType = startRouteItemRaw.itemType,  --路径对应的itemType
                startItemId = startRouteItemRaw.id,     --路径起始的itemid
                endItemId = nil,                        --路径结束的itemid
                initLength = 0,                         --初始化时候的计数，这条路的起始长度
                currLength = 0,                         --当前路径的长度
                coords = {},                            --坐标队列，不是所有路径都有（除非以后需要）
                id = routeId,
            }
            table.insert(routeList, routeMap[routeId])
            
            local routeGlobal = routeMap[routeId] 
    
            -- mod 2 coords 
            if startRoute.coords then
                local info = UBFGameItemStaticConfig[startRouteItemRaw.itemType]
                local pathItemType = startRoute.pathType or info.routeGenType
                if not pathItemType then UBFThrow "生成路径模式找不到导出的路径类型" end

                local coords = startRoute.coords
                startRouteItemRaw.route = nil
                startRouteItemRaw.routeMaster = {
                    routeId = routeId,
                    routeRef = routeGlobal,
                }
                
                routeGlobal.coords = coords
                routeGlobal.initLength = #coords
                routeGlobal.currLength = routeGlobal.initLength
                routeGlobal.itemType = pathItemType
                routeGlobal.isLoop = startRoute.isLoop

                if routeGlobal.initLength == 0 then UBFThrow "路径数据异常，没有路径？" end

                local routeItemList = {}

                for i = 1 , routeGlobal.initLength do 
                    local coord = coords[i]

                    local route = {
                        isStart = false,
                        isEnd = false,
                        index = i,
                        routeId = routeGlobal.id,
                        routeRef = routeGlobal,
                    }

                    if routeGlobal.isLoop then 
                        if i == 1 then 
                            route.isStart = true
                            route.isEnd = true 
                        end
                    else
                        route.isStart = i == 1
                        route.isEnd = i == routeGlobal.initLength 
                    end

                    local gridContext = boardContext:getGridContextByPos(coord.r, coord.c)

                    local routeItemContext = boardContext:buildNewItem({
                        itemType = pathItemType,
		                fixedRefFields = { 
                            route = route
                        },
                    })
                    local routeItemRawContext = routeItemContext:getRawData()
                    table.insert(newRouteItemList, routeItemRawContext)
                    routeItemContext:release()

                    if route.isStart then 
                        routeGlobal.startItemId = routeItemRawContext.id
                    end

                    if route.isEnd then 
                        routeGlobal.endItemId = routeItemRawContext.id
                    end

                    table.insert(routeItemList, routeItemRawContext)
                    gridContext:addItemContext(routeItemRawContext)

                    gridContext:release()
                end

                for i , routeItemRawContext in ipairs(routeItemList) do 
                    local route = routeItemRawContext.route
                    if i > 1 then 
                        local prevRoute = routeItemList[i - 1].route
                        prevRoute.nextItemId = routeItemRawContext.id
                        route.prevItemId =  routeItemList[i - 1].id
                        UBFFeatureHelper:_updateRouteState(routeItemList[i - 1], routeItemRawContext)
                    end
                end

                if routeGlobal.isLoop then 
                    local last = routeItemList[#routeItemList]
                    local first = routeItemList[1]
                    last.route.nextItemId = first.id
                    first.route.prevItemId = last.id
                    UBFFeatureHelper:_updateRouteState(last, first)
                end

            else
                local currRouteItem = startRouteItemRaw
            
                while currRouteItem do
                    local route = currRouteItem.route
                    --设置引用和id
                    route.routeRef = routeGlobal
                    route.routeId = routeId
                    route.isStart = false
                    route.isEnd = false
                    --起始长度更新
                    routeGlobal.initLength = routeGlobal.initLength + 1
                    route.index = routeGlobal.initLength
                    --如果没有下一个节点
                    if not route.next then 
                        break 
                    end
                    --获取下一个
                    local gridRawContext = posMap[route.next.r * MACRO_POS_STRIDE + route.next.c]
        
                    local nextItemRaw = nil
        
                    --先来检查是否到循环头了
                    if gridRawContext[UBFGridContext.itemIdMapKey][routeGlobal.startItemId] then
                        nextItemRaw = gridRawContext[UBFGridContext.itemIdMapKey][routeGlobal.startItemId] 
                    else
                        --没到循环头，获取下一个

                        --先处理是否为多格路径类，选择body
                        local nextItemContextRawList = gridRawContext[UBFGridContext.itemTypeMapKey][UBFGameItemType.kBody]
                        if nextItemContextRawList then 
                            for _ , itemContextRaw in ipairs(nextItemContextRawList) do 
                                if startRouteItemRaw.id ==  itemContextRaw.headId 
                                    and itemContextRaw.route and not itemContextRaw.route.routeId 
                                then 
                                    nextItemRaw = itemContextRaw
                                    break
                                end
                            end
                        end

                        --如果不是多格路径类的，说明是普通连锁类
                        if not nextItemRaw then 
                            nextItemContextRawList = gridRawContext[UBFGridContext.itemTypeMapKey][currRouteItem.itemType]
                            for _ , itemContextRaw in ipairs(nextItemContextRawList) do 
                                --选择一个没有被初始化的路径进行分配，通常不会遇到情况，因为同样类型的路径不会相互压着
                                if itemContextRaw.route and not itemContextRaw.route.routeId then 
                                    nextItemRaw = itemContextRaw
                                    break
                                end
                            end
                        end

                        --再没有报错
                        if not nextItemRaw then 
                            UBFThrow( string.format( "路径解析异常，关卡编辑器宣称存在，但实际寻找不到：%d,%d" , route.next.r , route.next.c ) )
                        end
                    end

                    --处理当前路径状态
                    local nextRoute = nextItemRaw.route
        
                    --赋值id
                    route.nextItemId = nextItemRaw.id
                    nextRoute.prevItemId = currRouteItem.id
        
                    --清理原来的数据
                    route.next = nil 
                    route.isLoop = nil
        
                    --刷新状态
                    UBFFeatureHelper:_updateRouteState( currRouteItem , nextItemRaw )
        
                    --遍历下一个
                    currRouteItem = nextItemRaw
        
                    --检查循环退出
                    if currRouteItem.id == routeGlobal.startItemId then break end
                end
        
                startRoute.isStart = true
                currRouteItem.route.isEnd = true
                routeGlobal.endItemId = currRouteItem.id
                if routeGlobal.initLength == 1 then routeGlobal.isLoop = currRouteItem.route.nextItemId == currRouteItem.id
                else routeGlobal.isLoop = routeGlobal.endItemId == routeGlobal.startItemId end
                routeGlobal.currLength = routeGlobal.initLength
            end
        end
    end

    return newRouteItemList
end

function UBFGameBoardLogic:_findBoardExistColorList( boardContext )
    local colorMap = {}
    local list = {}
    
    -- local _posMap = boardContext:getGridPosMap()

    -- for k , gridRaw in pairs(_posMap ) do
    --     local itemMaster = gridRaw.itemMaster
    --     if itemMaster and itemMaster.isColorful then 
    --         if itemMaster.color > 0 then 
    --             if not colorMap[itemMaster.color] then 
    --                 colorMap[itemMaster.color] = true
    --                 table.insert(list, itemMaster.color)
    --             end
    --         end
    --     end
    -- end

    local boardBorder = boardContext:getValue( "boardBorder" )
    local topBorder = boardBorder.top
	local bottomBorder = boardBorder.bottom
	local leftBorder = boardBorder.left
	local rightBorder = boardBorder.right

    local height = bottomBorder - topBorder + 1
    local width = rightBorder - leftBorder + 1
    local boardMap = boardContext:getBoardMap()

    -- 小动物、特效、大眼仔、染色宝宝、萌豆、闪电鸟、发条、蝴蝶
    -- todo 回头接入features
    local NeedCheckColorItemMap = {
        -- [UBFGameItemType.kAnimal] = true,
        -- [UBFGameItemType.kMagicLamp] = true,
        [UBFGameItemType.kColorRobot] = true,
        [UBFGameItemType.kTotems] = true,
        -- [UBFGameItemType.kBottleBlocker] = true,
        -- [UBFGameItemType.kTotems] = true,
        -- [UBFGameItemType.kCuckooWindupKey] = true,
        -- [UBFGameItemType.kButterfly] = true,
    }
    
    local BlackColorItemMap = {
    }

	for r = 1 , height do 
		for c = 1 , width do 
            local _r , _c = r + topBorder - 1, c + leftBorder - 1
            local gridContextRaw = boardMap[_r] and boardMap[_r][_c]
            local itemMaster = gridContextRaw and gridContextRaw.itemMaster
            if itemMaster and not BlackColorItemMap[itemMaster.itemType] and (itemMaster.isColorful or NeedCheckColorItemMap[itemMaster.itemType]) then 
                if itemMaster.color > 0 then 
                    if not colorMap[itemMaster.color] then 
                        colorMap[itemMaster.color] = true
                        table.insert(list, itemMaster.color)
                    end
                end
            end
		end
	end

    return list
end

function UBFGameBoardLogic:_findGameTargetColorList(boardContext)
    local colorMap = {}

    local targetMap = self:leagueCall("getTargetMap")
    for tallyId in pairs(targetMap) do
        if UBFTallyColorMap[tallyId] then 
            colorMap[UBFTallyColorMap[tallyId]] = UBFTallyColorMap[tallyId]
        end
    end

    return UBFHelper:toList(colorMap)
end

--对应operation的init操作，游戏开始调用
function UBFGameBoardLogic:gameStartInit(initData)
    local boardId = 1
    local boardContext = self.levelContext:getBoardContext( boardId )
    local currFrameIndex = self:getCurrLogicFrameIndex()

    local gEnv = self.levelContext:getValue(UBFLevelContext.gameEnvKey)
    self.low_device = nil

    --低端机数据记录
    if gEnv.isLowDevice 
        or (
            EnvUtil:isMiniGame()
            and (_G.UBF_BOARD_FORCE_NOT_JUMP_FRAME 
                or _G.UBF_BOARD_FORCE_FAST_MODE)
        )
    then
        --小游戏全是慢的
        self.low_device = {
            auto_collect = gEnv.isLowDevice,
            force_wait_frame = _G.UBF_BOARD_FORCE_NOT_JUMP_FRAME,
            force_fast_mode = _G.UBF_BOARD_FORCE_FAST_MODE,
        }
    end

    self:addModList( initData.modList , boardContext)

    self:callById(self.fuuuGraphLogicId, "startInit", initData.fGraph)
    self:callById(self.levelDiffChangeLogicId, "onStartLevel")

    local refreshIdMap = {}
    local event = UBFGameEventBusLogic:getEvent(UBFGamePlayEventEnum.kGameInit, { refreshIdMap = refreshIdMap })
    UBFGameEventBusLogic:dispatch(self, boardContext, event)

    local viewInfos = {}
    for id, _ in pairs(refreshIdMap) do 
        local itemContext = UBFContextManager:pack(boardContext:filterItemRawDataById(id))
        if itemContext then 
            local info = itemContext:getViewInfo()
            if info then 
                info.pos = itemContext:getValue("pos")
                table.insert(viewInfos, info) 
            end
            itemContext:release()
        end
    end
    
    if #viewInfos > 0 then 
        --创建或者更新已有的数据，都是这个接口，very good!
        self:sendViewActionList({ 
            UBFViewActionData:create( 
                UBFViewActionType.kItemCreate ,  
                { items = viewInfos, postInit = true } ,  
                currFrameIndex 
            ) 
        }) 
    end

    boardContext:release()

end

--on_init_state_finish
function UBFGameBoardLogic:onInitStateFinish()

    local boardContext = self.levelContext:getBoardContext(1)
    local checkPosList = {}
    local boardBorder = boardContext:getValue("boardBorder")
    for r = boardBorder.top, boardBorder.bottom do
        for c = boardBorder.left, boardBorder.right do
            table.insert(checkPosList, { r = r, c = c })
        end
    end

    local currLogicFrameIndex = self:getCurrLogicFrameIndex()
    self:createAndAddLogicAction(UBFLogicActionType.kItemCheckMatch,  {
        checkSource = "init",
        checkPosList = checkPosList,
        boardId = 1,
        fullCheck = true,
        forceCheck = true,
    }, currLogicFrameIndex)

    boardContext:release()
end

--------------------****** *↓* ******--------------------
--				        主循环部分
--------------------****** *↑* ******--------------------

function UBFGameBoardLogic:stopMainLoop()
    if self._onSchedule then 
        local timer = UBFThreadBridge:getThread( self.threadId ):getTimer()
        timer:removeLoop(self._onSchedule)
        self._onSchedule = nil
    end
end

function UBFGameBoardLogic:startMainLoop()
    self:stopMainLoop()
    self._onSchedule = function() 
        local errMsg
        local ok, err = xpcall(function()
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

            return self:mainLoopUpdate() 
        end, function(msg)
            errMsg = tostring(msg) .. "\nlogic direct stack: " .. debug.traceback()
            return msg
        end)
        if not ok then 
            if not errMsg then errMsg = "unkown error msg? origin: " .. tostring(err) end
            self:sendToAgent(UBFPlayEventType.kCrash, errMsg) 
            self:stopMainLoop()
        end
    end
    local timer = UBFThreadBridge:getThread(self.threadId):getTimer()
    timer:addLoop( self._onSchedule )
end

function UBFGameBoardLogic:checkAndUpdateBoardIdle()
    local boardIdleState = self:checkBoardIdle()
    local lastBoardIdleState = self.levelContext:getValue( "lastBoardIdleState" )
    if lastBoardIdleState ~= boardIdleState then 
        self.levelContext:setValue("lastBoardIdleState", boardIdleState)
        local runnableOrderList = self:getRunnableBoardIdList()
        for _, boardId in ipairs(runnableOrderList) do 
            self:sendBoardStateChange(boardId, UBFBoardStateKey.kCanSwap,
                boardIdleState and self:getGamePlayState() == UBFGamePlayState.kRun)
        end
        self:updateThreadFPS()
    end
end

function UBFGameBoardLogic:updateThreadFPS()
    if UBFThreadBridge:isCurrThreadIsMain() then return end
    local timer = UBFThreadBridge:getThread():getTimer()
    if UBFGameEnv:is(UBFGameEnvKey.AUTO_PLAY_AI_MODE) then
        timer:setFPS(12000)
        return
    end
    local fps = self:isBoardIdle() and 30 or 12000
    timer:setFPS(fps)
end

function UBFGameBoardLogic:mainLoopUpdate( )
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


    --强制等待帧数，低性能机器会使用的模式
    if self._waitFrameJump then 
        self._waitFrameJump = self._waitFrameJump - 1
        if self._waitFrameJump <= 0 then self._waitFrameJump = nil 
        --
--

        else return end
    end

    --挑选并进行操作
    self:callById(self.operationLogicId, "updateOperations")

    --决策是否可以继续
    local judgeResult = self:callById(self.judgeLogicId, "allowContinue")
    if not judgeResult then
        --检查idle状态 
        self:checkAndUpdateBoardIdle()
        return 
    end

    --检查idle状态 
    self:checkAndUpdateBoardIdle()

    --更新状态机
    local runnableOrderList = self:getRunnableBoardIdList()
    for _, boardId in pairs(runnableOrderList) do
        self:callById(self.stateMachineIdMap[boardId], "update")
    end

    --更新所有action
    local finResult , nextFrameId = self:callById( self.logicActionManagerId , "mainLoopUpdate" )
    if finResult == false and nextFrameId 
        -- and false --要测试，暂时打开
        then
        --todo 跳过空帧
        local _currIndex = self:callById( self.logicActionManagerId , "getCurrLogicFrameIndex" )
        -- printx( 1 , "UBFGameBoardLogic:mainLoopUpdate   跳过空帧 nextFrameId:" , nextFrameId , "_currIndex:" , _currIndex , "addCurrLogicFrameIndex:" , nextFrameId - _currIndex )
        local dframe = nextFrameId - _currIndex
        self:callById( self.logicActionManagerId , "addCurrLogicFrameIndex", dframe)
        if self.low_device and self.low_device.force_wait_frame then
            self._waitFrameJump = dframe - 1 
            if self._waitFrameJump <= 0 then self._waitFrameJump = nil end
        end

        --模拟随机崩溃
        -- if UBFRandom:calcValue( math.random(0xffffffff) , 1 , 10000 ) < _currIndex then a = b + 8 end 
    end

    --更新判决逻辑
    self:callById(self.judgeLogicId, "update")

    --更行board缓存
    local boardContext = self.levelContext:getBoardContext(1)
    self:updateItemAddAndDel(boardContext, boardContext:getAddelItemData())
    boardContext:loopUpdate()
    boardContext:release()

    --断面
    self:updateSecionFlagOperate()

    --切关
    if self.theNextWorld then 
        self:stopMainLoop()
        self:sendToAgent(UBFPlayEventType.kChangeLevel, self.theNextWorld)
        return
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

end

--处理item的增删
function UBFGameBoardLogic:updateItemAddAndDel( boardContext , itemAddelMap )

    for itemType , addelData in pairs( itemAddelMap ) do 
        
        local addList = addelData.add --item本帧添加到了棋盘活动区域
        local delList = addelData.del --item本帧从棋盘活动区域移除

        if #addList > 0 then 
            local event = UBFGameEventBusLogic:getEvent( UBFGamePlayEventEnum.kItemEnter , { itemAddelMap = itemAddelMap } )
            UBFGameEventBusLogic:dispatchTargetItemList( self , boardContext , itemType , addList , event )
        end 

        if #delList > 0 then 
            local event = UBFGameEventBusLogic:getEvent( UBFGamePlayEventEnum.kItemExit , { itemAddelMap = itemAddelMap } )
            UBFGameEventBusLogic:dispatchTargetItemList( self , boardContext , itemType , delList , event )
            if addelData.empty then boardContext:onItemRemoveUpdateEventContext( itemType ) end
        end

    end
    
end

--处理断面flag
function UBFGameBoardLogic:updateSecionFlagOperate()

    if self.takeSectionFlag then 
        -- 发送断面记录信息，记录当前断面
        local isPoint = self.takeSectionFlagPoint
        self.takeSectionFlagPoint = nil
        --暂时不考虑多棋盘
        local flagType = self.takeSectionFlag
        self.takeSectionFlag = nil
        self:doTakeSection(flagType, isPoint)
        self.takeSectionExtra = nil
    end

    if self.resumeSectionFlag then 
        local sectionId = self.resumeSectionFlag
        local destiny = self.roadsOfDestiny
        self.resumeSectionFlag = nil
        self.roadsOfDestiny = nil
        self.takeSectionFlag = nil
        self:sendToAgent( 
            UBFPlayEventType.kResumSection,
            sectionId,
            { moveCount = self:leagueCall("getRestMoveCount") },
            destiny
        )
    end
end

--------------------****** *↓* ******--------------------
--				        棋盘操作部分
--------------------****** *↑* ******--------------------

-- replayLog 就是旧棋盘的 oplog
function UBFGameBoardLogic:launchReplayMode(replayLog)
    self:callById( self.operationLogicId , "launchReaply" , replayLog )
end

--断面后退一步时候的巧用
function UBFGameBoardLogic:onSectionBackOperation(backedOpData)
    self:callById(self.operationLogicId, "onSectionBackOperation", backedOpData)
end

function UBFGameBoardLogic:onPushOperation(event, action)
    local boardId = action.boardId
    local opType = action.type
    local params = action.params
    self:pushOperation( opType , params , boardId )
end

--推入操作，推入不代表真正执行，但会进入执行队列
function UBFGameBoardLogic:pushOperation(opType, params, boardId)
    self:callById(self.operationLogicId, "pushOperation", opType, params, boardId)
end

--真正执行处理各种操作的地方
--操作来源可能是玩家，也可能是replay，也可能是ai
--boardId已经废弃，操作只有1
function UBFGameBoardLogic:doOperation(boardId, opType, params, opId)
    local currLogicFrameIndex = self:getCurrLogicFrameIndex()

    if opType == UBFOperationType.kDestiny then return self:whatDestiny(params) end      
    
    --
--


    local playState = self:getGamePlayState()
    if playState == UBFGamePlayState.kAlmostFail then
        --即将失败状态不在跑action，只能够进行两种操作，一种是复活，另外一种是放弃
        self:executeOperationLogic(boardId, opType,  params, opId)
    else
        self:createAndAddLogicAction( UBFLogicActionType.kDoOperation , {
            boardId = boardId,
            opType = opType,
            params = params,
            opId = opId,
        } , currLogicFrameIndex + 1 )

        local markSection = true
        if opType == UBFOperationType.kProp then
            if params.propUnitType == UBFPropUnitType.kRevert then 
                markSection = false
            end
        elseif opType == UBFOperationType.kAbandon then
            markSection = false
        end
        if markSection then 
            self:markTakeSection(UBFSectionType.kFast, true, { byOperation = opType }) 
        end
    end
end

function UBFGameBoardLogic:executeOperationLogic(boardId, opType, params, opId)
    self:leagueCall("onOperation", boardId, opType)

    --只记录主棋盘
    local boardContext = self.levelContext:getBoardContext(1)
    self:callById(self.btLaunchLogicId, "setLastOperationType", boardContext, opType, params)
    boardContext:release()

    local importantSiteMap = self.levelContext:getValue("importantSiteMap")
	if importantSiteMap.onBeforeOperation then 
		local params = { 
			opType = opType,
			params = params,
		}
		for _, runner in ipairs(importantSiteMap.onBeforeOperation) do 
			UBFFeatureHelper:doCommonRunner(self, boardContext, runner, params)
		end
	end

    -- todo 临时写写
    if opType == UBFOperationType.kSwap then                                                
        self:trySwap( 
            params.r ,  params.c , 
            params.tr , params.tc , 
            boardId , 
            params.fullCheck , 
            params.passMatchCheck ,
            opId , 
            params.state
        )
    elseif opType == UBFOperationType.kProp then
        local propUnitType = params.propUnitType
        if propUnitType == UBFPropUnitType.kRefresh then 
            -- if __WIN32 then self:_refreshTest() end
            self:tryRefresh(boardId, nil, { byUseProp = true })
            self:changeFSMState(UBFConst.BoardSMKey.kFalling, boardId)
        elseif propUnitType == UBFPropUnitType.kRevert then 
            self:markResumeSection(params.sectionId)
        elseif propUnitType == UBFPropUnitType.kAddStep5 then 
            local addStepExtra = { source = { sourceId = UBFModSourceIdEnum.kProp }, skipFlyAnimation = params.skipFlyAnimation }
            self:tryAddStep(params.addStepCount or 5,  params.isRevival, nil, addStepExtra)
        elseif propUnitType == UBFPropUnitType.kAddStep15 then 
            local addStepExtra = { source = { sourceId = UBFModSourceIdEnum.kProp } }
            self:tryAddStep(15, false, nil, addStepExtra)
        else
            local treedata = { 
                trigger = UBFGameBTreeTriggerType.onProp,   
                propUnitType = propUnitType,  
                points = params.points,
                boardId = boardId,
                property = params.property
            }
            local result = self:runBTree(treedata)
            if result then self:changeAllFSMState(UBFConst.BoardSMKey.kFalling) end
        end
        self:callById(self.productItemLogicId, "refreshRules", boardContext, UBFProduceTriggerEvent.kUseProp)
    elseif opType == UBFOperationType.kAbandon then 
        local mode = params.mode
        if mode == UBFOperationAbandonType.kGiveUp then 
            self:callById(self.judgeLogicId, "giveUp")
        elseif mode == UBFOperationAbandonType.kDropout then 
            self:callById(self.judgeLogicId, "dropout")
        elseif mode == UBFOperationAbandonType.kRetry then 
            self:callById(self.judgeLogicId, "retry")
        end
    elseif opType == UBFOperationType.kInit then 
        self:gameStartInit( params )
    elseif opType == UBFOperationType.kUseBuff then
        local boardContext = self.levelContext:getBoardContext( boardId )
        self:addModList(params.buffList, boardContext)
        boardContext:release()
        self:changeFSMState(UBFConst.BoardSMKey.kFalling, boardId)
    elseif opType == UBFOperationType.kMod then
        local boardContext = self.levelContext:getBoardContext(boardId)
        local itemType = params.itemType
        local event = UBFGameEventBusLogic:getEvent(UBFGamePlayEventEnum.kOperation, { 
            params = params,
            boardId = boardId
        })
        self:tryHandleOfflineMatchTimeout(params, event)
        UBFGameEventBusLogic:dispatchTargetItemType(self, boardContext, itemType, event)
        boardContext:release()
        if not event:isNotoFalling() then --todo fix 反转isNotoFalling
            self:changeFSMState(UBFConst.BoardSMKey.kFalling, boardId) 
        end
    end

    local event = UBFGameEventBusLogic:getEvent(UBFGamePlayEventEnum.kAfterOperationExecuted, { 
        opType = opType,
        opId = opId,
        opParams = params,
    })
    UBFGameEventBusLogic:dispatch(self, boardContext, event)    
end

function UBFGameBoardLogic:tryHandleOfflineMatchTimeout(params, event)
    if not params then return end
    if params.sourceId ~= UBFModSourceIdEnum.kOfflineMatch then return end
    if params.op ~= "OfflineMatchTimeout" then return end

    if event and event.setNotoFalling then
        event:setNotoFalling()
    end

    local playState = self:getGamePlayState()
    if playState ~= UBFGamePlayState.kWin and playState ~= UBFGamePlayState.kFail then
        self:callById(self.judgeLogicId, "changeGamePlayState", UBFGamePlayState.kWin, {
            reason = params.op,
        })
    end
end

function UBFGameBoardLogic:whatDestiny(destiny)
    if destiny.disturber == UBFDestinyDisturber.kHell then
        self:markResumeSection(destiny.theEnd, destiny)
    elseif destiny.disturber == UBFDestinyDisturber.kForward then
        self.theNextWorld = destiny
    end
end

function UBFGameBoardLogic:trySwap( r , c , tr , tc , boardId , fullCheck , passMatchCheck , matchFeedbackId , swapState )
    local currLogicFrameIndex = self:getCurrLogicFrameIndex()
    local datas = { 
        r = r , c = c , tr = tr , tc = tc , boardId = boardId, 
        fullCheck = fullCheck , passMatchCheck = passMatchCheck,
        matchFeedbackId = matchFeedbackId,
        swapState = swapState, -- swapState 是带给视图的状态码，逻辑预期不用
    }
    self:createAndAddLogicAction(UBFLogicActionType.kItemTrySwap, datas, currLogicFrameIndex)
    self:leagueCall("onSwap")
    local currSMState = self:getFSMState(boardId) 
    if currSMState ~= UBFConst.BoardSMKey.kWating then 
        self:leagueCall("popSwapMark")
        self:onTakeStep(boardId)
    end
end

--计算刷新棋盘结果，不会对棋盘造成任何处理
function UBFGameBoardLogic:_calcRefresh(boardContext, seed, boardBorder, extra)
    extra = extra or {}
    local boardBorder = boardBorder or boardContext:getValue( "boardBorder" )

    local refreshLogic = UBFRandomColorHelper:createRefreshLogic()
        :setOccasion(UBFCalcColorOccasion.kCommonRefresh)

    if extra.onlyAnimal then refreshLogic:setOnlyAnimalCanChange(true) end
    if extra.passGroupIndex then refreshLogic:setPassGroupIndex(true) end
    if extra.onlyCheckGroupIndex then refreshLogic:setOnlyCheckGroupIndex(extra.onlyCheckGroupIndex) end

    refreshLogic:loadGirdMap(boardContext, boardBorder)

    local result = {}

    --清除可选颜色的颜色
    refreshLogic:toColourless()
    --进入池子
    local poolData = refreshLogic:toPool()
   
    result.moveRuntime = refreshLogic:createMoveRuntime( poolData )
    result.refreshLogic = refreshLogic 
    
    local hasSwap = false

    if extra.veryAreaSwap then 
        local swapCount, totalCount = refreshLogic:ensureOneMatchSwapInVeryArea(seed)
        if swapCount > 0 then 
            hasSwap = true
            if swapCount ~= totalCount then result.badSwapInVeryArea = true end
        else
            hasSwap = refreshLogic:ensureOneMatchSwap(seed)
        end
    else
        hasSwap = refreshLogic:ensureOneMatchSwap(seed)
    end

    -- result.refreshLogic:printMap( 21 )

    if not hasSwap then 
        --尝试让特效匹配
        hasSwap = refreshLogic:ensureOneSpecialSwap( seed ) 
        result.ensureSpeical = true
    end

    if not hasSwap then 
        -- 还没有? 山穷水尽了，如果不允许连续，则走人
        if extra.passEnsureContinuity then return false end
        --为了不死，尽可能弄出一个带有三连的盘面
        hasSwap = refreshLogic:ensureLeastOneContinuity( seed )
        result.ensureContinuity = true
        --还没有？行吧，放弃吧
        if not hasSwap then return false end
    else
        --确定颜色
        local hasBad = refreshLogic:ensureNoContinuity( seed )
        if hasBad then result.badEnsussre = true end
    end

    return hasSwap , result
end

function UBFGameBoardLogic:_calcRefreshMutil(boardContext, seed, boardBorder, calcExtra)
    local hasSwap, result = self:_calcRefresh(boardContext, seed, boardBorder, calcExtra)

    if not hasSwap then 
        if calcExtra.noCheckGroupIndex then return false end
        calcExtra = calcExtra or {}
        calcExtra.passGroupIndex = true
        hasSwap, result = self:_calcRefresh(boardContext, seed, boardBorder, calcExtra)
        if not hasSwap then return false end
    end

    if result.badEnsussre then
        -- printx(21, "oh my god!") 
        local vSeed = seed
        for i = 1 , 3 do 
            vSeed = UBFRandom:nextSeed( vSeed )
            local newHasSwap , newResult = self:_calcRefresh( boardContext , vSeed , boardBorder , calcExtra )
            if newHasSwap and not newResult.badEnsussre then 
                hasSwap = newHasSwap
                result = newResult
                -- printx(21, "but nice!")
                break 
            end
        end
    end

    return hasSwap , result
end

function UBFGameBoardLogic:_calcRefreshMutilByArea(boardContext, seed, boardBorder, calcExtra, refreshAreaList)
   
    local hasSwap, result
    calcExtra.noCheckGroupIndex = true

    for _, index in ipairs(refreshAreaList) do 
        if index > 1 then 
            calcExtra.onlyCheckGroupIndex = index
            hasSwap, result = self:_calcRefreshMutil(boardContext, seed, boardBorder, calcExtra)
            if hasSwap then break end
        end
    end

    calcExtra.onlyCheckGroupIndex = nil
    calcExtra.noCheckGroupIndex = false

    return hasSwap , result
end

--测试算法
function UBFGameBoardLogic:_refreshTest( seed )
    local boardContext = self.levelContext:getBoardContext( 1 )
    local boardBorder = boardContext:getValue( "boardBorder" )

    seed = seed or math.random(0xffffffff)

    local n = 10000

    local hasSwapCount = 0
    local hasBadCount = 0
    local hasContinuityCount = 0

    UBFLuaHelper:nextClock() 
    for i = 1 , n do 
        seed = UBFRandom:nextSeed( seed )
        local hasSwap , result = self:_calcRefresh( boardContext , seed , boardBorder )
        if hasSwap then hasSwapCount = hasSwapCount + 1 end
        if result.badEnsussre then 
            hasBadCount = hasBadCount + 1 
            -- for i = 1 , 3 do 
            --     seed = UBFRandom:nextSeed( seed )
            --     hasSwap , result = self:_calcRefresh( boardContext , seed , boardBorder )
            --     if not result.badEnsussre then break end
            -- end
        end
        if result.refreshLogic:checkHasContinuity() then hasContinuityCount = hasContinuityCount + 1 end
    end
    local dts = UBFLuaHelper:nextClock() / 1000

    printx(21, string.format(
        "测试刷新-> 运行了%d次, 共花费了%.2fms, 成功交换:%d, 异常三连:%d, 三连:%d" , 
        n , dts , 
        hasSwapCount , hasBadCount,
        hasContinuityCount
    ))
end

function UBFGameBoardLogic:tryRefresh( boardId , seed , extra )
    local boardContext = self.levelContext:getBoardContext( boardId or 1 )
    local posMap = boardContext:getGridPosMap()
    local boardBorder = boardContext:getValue( "boardBorder" )

    local seed = seed or boardContext:nextSeed()

    -- if UBF_USE_NEW_REFRESH_LOGIC then
    local passEnsureContinuity = extra and extra.passEnsureContinuity
    local calcExtra = { passEnsureContinuity = passEnsureContinuity }

    -- if extra and extra.byUseProp then 
    --     calcExtra.onlyAnimal = true
    -- end

    --刷新步骤
    --[[
        step 1 刷新动物，如果没有走一步三消
        step 2 刷新全部，如果没有走一步三消
        step 3 使用可以三连的
    ]]

    --是否要求全部刷新，包括任何可变色的，相当于直接到了step 2
    local startStep2 = extra and extra.forceAll or false
    if not startStep2 then calcExtra.onlyAnimal = true end

    local hasSwap, result 

    -- if true then 
    --     local refreshAreaList = boardContext:getValue("refreshAreaList")
    --     if refreshAreaList then 
    --         hasSwap, result = self:_calcRefreshMutilByArea(boardContext, seed, boardBorder, calcExtra, refreshAreaList)
    --     end
    -- end
    
    if not hasSwap then 
        hasSwap, result = self:_calcRefreshMutil(boardContext, seed, boardBorder, calcExtra)
    end

    if not hasSwap then 
        --没有可交换的？如果已经是全部了，那就GG了
        if startStep2 then return false end
        --尝试刷新全部
        hasSwap , result = self:_calcRefreshMutil( boardContext , seed , boardBorder , { passEnsureContinuity = passEnsureContinuity } )
        --实在没得换，死了
        if not hasSwap then return false end
    elseif result.badEnsussre or result.ensureContinuity then 
        --可恶，还是有三连，如果不是从step2开始的，再来一次
        if not startStep2 then 
            --尝试刷新全部
            local newHasSwap , newResult = self:_calcRefreshMutil( boardContext , seed , boardBorder , { passEnsureContinuity = passEnsureContinuity } )
            if newHasSwap then hasSwap , result = newHasSwap , newResult end 
        end
    end

    local moveRuntime = result.moveRuntime

    --debug
    -- 65 2853078140
    -- result.refreshLogic:printMap( 21 )
    -- if refreshLogic:checkHasContinuity() then 
        -- printx(21, "99 shit!" , boardContext:getBoardSeed() )
    -- end

    local moveDataList = {}
    local changeColorDataList = {}

    local function toMove( itemRaw , toGrid )
        local girdPos = itemRaw.pos
        if girdPos.r == toGrid.r and girdPos.c == toGrid.c then return end

        local currMoveData = { 
            r = girdPos.r , 
            c = girdPos.c , 
            tr = toGrid.r , 
            tc = toGrid.c , 
        }
        table.insert(moveDataList, currMoveData)

        local originGridContext = UBFContextManager:pack(posMap[girdPos.r * MACRO_POS_STRIDE + girdPos.c])
        
        -- mater
        originGridContext:removeItemContext( itemRaw , true )
        currMoveData.item = itemRaw
        
        -- followMaster
        if originGridContext:getValue( "hasMFFItems" ) then 
            local itemList = originGridContext:getItemList()
            currMoveData.followItemList = {}
            for _ , _itemRawData in ipairs( itemList ) do 
                if _itemRawData.followMasterFalling and _itemRawData ~= itemRaw then
                    table.insert( currMoveData.followItemList , _itemRawData )
                end
            end
            for _ , _itemRawData in ipairs( currMoveData.followItemList ) do
                originGridContext:removeItemContext( _itemRawData , true )
            end
        end
        
        originGridContext:release()
    end

    local function toColorChangeList( itemRaw )
        table.insert( changeColorDataList , itemRaw )
        boardContext:indexUpdateFieldChange( itemRaw )
    end
    
    -- result.refreshLogic:printMap( 21 )

    --进行位移
    moveRuntime:orderAllocate( function(  r , c , moveItemRaw , piece )
        if moveItemRaw.color ~= piece.color or piece.oldColor then 
            moveItemRaw.color = piece.color
            toColorChangeList( moveItemRaw )
        end
        toMove( moveItemRaw , { r = r , c = c } ) 
    end )
    
    --添加更新数据
    for _ , moveData in ipairs( moveDataList ) do 
        local toGridContext = UBFContextManager:pack(posMap[moveData.tr * MACRO_POS_STRIDE + moveData.tc])
        
        --更新数据
        toGridContext:addItemContext( moveData.item , true )
        if moveData.followItemList then
            for _ , item in ipairs( moveData.followItemList ) do
                toGridContext:addItemContext( item , true )
            end
        end
       
        --刷新状态
        toGridContext:setValue( "fallingState" , GridFallingState.kFalling )
        toGridContext:updateGridState()
        toGridContext:release()
    end

    --发送动画和action

    local frameLength = 45
    local currLogicFrameIndex = self:getCurrLogicFrameIndex( boardId )
    local changeList = {}
    local checkPosMap = {}
    local gridPosUpdateList = {}

    for k , v in ipairs( moveDataList ) do 
        table.insert( changeList , { id = v.item.id , tr = v.tr , tc = v.tc } )
        if v.followItemList then 
            for _ , item in ipairs( v.followItemList ) do
                table.insert( changeList , { id = item.id , tr = v.tr , tc = v.tc } )
            end
        end

        table.insert( gridPosUpdateList , { tr = v.tr , tc = v.tc } )
        checkPosMap[v.tr * MACRO_POS_STRIDE + v.tc] = { r = v.tr , c = v.tc }
    end

    for k , item in ipairs( changeColorDataList ) do 
        table.insert( changeList , { id = item.id , color = item.color } )
        local r , c = item.pos.r , item.pos.c
        checkPosMap[r * MACRO_POS_STRIDE + c] = { r = r , c = c }
    end

    -- if _G.isLocalDevelopMode and #changeList == 0 then 
    --     UBFThrow("why change list is empty but can swap! at frame " .. currLogicFrameIndex)
    -- end

    self:sendViewActionList({ UBFViewActionData:create( 
        UBFViewActionType.kItemRefresh , 
        {  
            changeList = changeList,
            frames = frameLength ,
            boardId = boardId,
            byAuto = extra and extra.auotRefresh
        } , 
        currLogicFrameIndex ) 
    } )

    self:createAndAddLogicAction( UBFLogicActionType.kItemRefresh , {
        gridDataList = gridPosUpdateList ,
        boardId = boardId,
    } , currLogicFrameIndex + frameLength )

    self:createAndAddLogicAction( UBFLogicActionType.kItemCheckMatch ,  {
        checkSource = "refresh" ,
        checkPosList = UBFHelper:toList( checkPosMap ),
        boardId = boardId ,
        fullCheck = true
    } ,  currLogicFrameIndex + frameLength + 1 )

    self:changeFSMState(UBFConst.BoardSMKey.kFalling, boardId)

    self:onBoardElementChange( boardContext )

    boardContext:release()

    return hasSwap
end

-- rust 里面被拆分了
function UBFGameBoardLogic:tryAddStep(addCount, isRevival, needPlayCustomAnimate, extra) 
    extra = extra or {}
    local skipFlyAnimation = extra.skipFlyAnimation
    self:leagueCall("addStep", addCount, isRevival, extra.source)
    self:callById(self.judgeLogicId , "update")
    if self:getFSMState(1) ~= UBFConst.BoardSMKey.kInit then 
        self:changeFSMState(UBFConst.BoardSMKey.kFalling, 1)
    end
    -- 复活的加步数，视图走状态切换逻辑，不走这里
    if not isRevival then 
        self:sendUIAction( UBFUIActionType.kTallyChange , { 
            tallyId = UBFTallyId.kMoveStep,
            tallyKind = UBFTallyKind.kCustom,
            addCount = addCount,
            count = self:leagueCall("getRestMoveCount"),
            needPlayCustomAnimate = needPlayCustomAnimate,
            skipFlyAnimation = skipFlyAnimation
        } , 1 )
    end

    local boardContext = self.levelContext:getBoardContext( 1 )
    local event = UBFGameEventBusLogic:getEvent( UBFGamePlayEventEnum.kAfterAddStep , { 
        addCount = addCount,
        isRevival = isRevival
    } )
    UBFGameEventBusLogic:dispatch( self , boardContext , event )
    boardContext:release()
end

function UBFGameBoardLogic:tryAddTempProps(propList, info)
    if EnvUtil:isMiniGame() then
        for _, prop in ipairs(propList) do 
            if prop.propUnitType == UBFPropUnitType.kRevert then 
                prop.propUnitType = UBFPropUnitType.kRefresh
            end
        end
    end

    local boardContext = self.levelContext:getBoardContext(1)
    self.levelContext:onTempPropAdd(propList)

    local event = UBFGameEventBusLogic:getEvent(UBFGamePlayEventEnum.kTempGift, { 
        propList = UBFHelper:shallowClone(propList),
        before = true
    })
    UBFGameEventBusLogic:dispatch(self, boardContext, event)

    self.messageManager:sendMessages({
        mType = UBFGameMessageType.kAddTempProp ,
        startFrameIdx = self:getCurrLogicFrameIndex(),
        propList = propList,
        info = info,
    })

    boardContext:release()
end


function UBFGameBoardLogic:addModList(modList, boardContext)
    modList = modList or {}
    local currFrameIndex = self:getCurrLogicFrameIndex()

    local gEnv = self.levelContext:getValue( UBFLevelContext.gameEnvKey )
    local modGrid = boardContext:getGlobalModGridContext()
    local boardId = boardContext:getBoardId()

    local items = {}
    local itemBuffTypeMap = {}

    for k , v in ipairs( modList ) do 
        local itemList = UBFPlayModBuilder:buildItemWithModData( v , gEnv.modSrcEnv[v.sourceId] )
        -- printx(16,itemList,tts(v))
        for k , item in ipairs( itemList ) do 
            local itemRaw = item and item:getRawData()
            -- printx(16,itemRaw.isMod)
            if itemRaw and itemRaw.isMod then 
                itemBuffTypeMap[itemRaw.itemType] = true
                modGrid:addItemContext( itemRaw , true ) 
                UBFFeatureHelper:onItemProduced(self, boardContext, modGrid, itemRaw)
                local info = item:getViewInfo()
                if info then 
                    info.pos = itemRaw.pos
                    table.insert(items, info) 
                end
            end
            item:release()
        end
    end

    --如果存在buff，则设置投掷buff的标记，和发送视图数据进行更新
    if #items > 0 then 

        local fsKey = self:getFSMState(boardId)
        local markTriigerType = UBFGameBTreeTriggerType.onBoardStable
        if fsKey == UBFConst.BoardSMKey.kInit then markTriigerType = UBFGameBTreeTriggerType.onBoardInit end
        local featureMap = self.levelContext:getValue("featureMap")
        local itemActions = require "ubf.UBFPlay.logics.logicActions.ItemInitAction"

        --根据静态配置，当mod加入游戏后，进行特殊的标记
        for itemType, _ in pairs(itemBuffTypeMap) do 
            if not featureMap[itemType] then
                local info = UBFGameItemStaticConfig[itemType]
                featureMap[itemType] = {}
                -- 这里补了一个额外信息，是因为lua这边很蠢，在初始化前就生成了viewInfo全完了，rust已经修改代码结构
                itemActions:initModByFeatures(self, { [1] = boardContext }, itemType, info.features, { items = items })
            end
            self:callById(self.btLaunchLogicId, "eventMark", boardContext , markTriigerType, itemType)
        end

        self:sendViewActionList({ UBFViewActionData:create( UBFViewActionType.kItemCreate ,  { items = items } ,  currFrameIndex ) })
    end
        
    modGrid:release()

    return items , itemBuffTypeMap
end

--------------------****** *↓* ******--------------------
--				         Get 多多
--------------------****** *↑* ******--------------------

function UBFGameBoardLogic:getRunnableBoardIdList()
    return self.levelContext:getMutilBoardOrderList("runnable")
end

--获取建议交换列表
function UBFGameBoardLogic:getBoardSwapProposeList(boardId, alwaysNew, checkMode)

    if alwaysNew then self.swapProposeListCache = nil end
    checkMode = checkMode or UBFCalcSwapProposesMode.NORMAL

    if not self.swapProposeListCache or checkMode > self.swapProposeListCacheCheckMode then 
        
        self.swapProposeListCacheCheckMode = checkMode

        --
--


        self.swapProposeListCache = self:callById(self.swapLogicId, "calcSwapProposes", 1, checkMode)

        --
--


        -- if _G.isLocalDevelopMode and not _G._ai_getBoardSwapProposeList then 
        --     _G.last_debug_game_board_logic_tryRefresh_launch_frame_ = debug.traceback()
        -- end
    end

    return self.swapProposeListCache
end

--给视图的数据的交换列表缓存，因为视图可能再任意时候需求，不能随便更新逻辑维护的缓存
function UBFGameBoardLogic:getBoardSwapProposeListForView(params)
    local lowMode = UBFLowPerformanceManager:isDisabled(UBFCalcHighConsumptionEnum.ZK_NEW_SWAP_TIP)
    if not self.swapProposeListCacheForView then 
        local checkMode = lowMode and UBFCalcSwapProposesMode.NORMAL or UBFCalcSwapProposesMode.FULL
        if self.low_device and self.low_device.force_fast_mode then checkMode = UBFCalcSwapProposesMode.FAST end
        if self.swapProposeListCache and checkMode <= self.swapProposeListCacheCheckMode then
            self.swapProposeListCacheForView = self.swapProposeListCache
        else
            self.swapProposeListCacheForView = self:callById(
                self.swapLogicId, "calcSwapProposes", 1, checkMode) 
        end
    end
    local boardContext = self.levelContext:getBoardContext(1)
    local swapTwoList = nil
    if not lowMode or (UBFGuideSwitchLogic and UBFGuideSwitchLogic:isEnableSmartGuideV2()) then
        require 'ubf.UBFPlay.logics.guide.UBFGuideSmartAdviceLogic'
        swapTwoList = UBFGuideSmartAdviceLogic:getAdviceTwoPos(self, boardContext, self.swapProposeListCacheForView, params)
    end 
    return {
        swapProposeList = self.swapProposeListCacheForView,
        swapTwoList = swapTwoList,
    }
end

function UBFGameBoardLogic:getGamePlayState()
    return self:callById( self.judgeLogicId , "getGamePlayState" )
end

function UBFGameBoardLogic:getLevelContext()
    return self.levelContext
end

function UBFGameBoardLogic:leagueCall( name , ... )
    return self:callById( self.leagueLogicId , name , ... )
end

function UBFGameBoardLogic:shadowTargetCall( name , ... )
    return self:callById( self.shadowTargetLogicId,name,... )
end


function UBFGameBoardLogic:judgeCall( name , ... )
    return self:callById( self.judgeLogicId , name , ... )
end

function UBFGameBoardLogic:productItemCall( name , ... )
    return self:callById( self.productItemLogicId , name , ... )
end

function UBFGameBoardLogic:fuuuGraphCall(name, ...)
    return self:callById(self.fuuuGraphLogicId, name, ...)
end

function UBFGameBoardLogic:getCurrLogicFrameIndex( )
    return self:callById( self.logicActionManagerId , "getCurrLogicFrameIndex" )
end

function UBFGameBoardLogic:isAllBoardInWaiting()
    for _, id in pairs(self.stateMachineIdMap) do 
        local state = self:callById(id, "getCurrStateKey")
        if state ~= UBFConst.BoardSMKey.kWating then return false end
    end
    return true
end

function UBFGameBoardLogic:checkBoardIdle()
    if not self:isAllBoardInWaiting() then return false end
    if self:hasLogicAction() then return false end
    return true
end

function UBFGameBoardLogic:isBoardIdle()
    return self.levelContext:getValue("lastBoardIdleState")
end

function UBFGameBoardLogic:hasLogicAction()
    local actionCount = self:callById( self.logicActionManagerId , "getActionCount" )
    return actionCount > 0
end

function UBFGameBoardLogic:createAndAddLogicAction( actionType , datas , startFrameIdx , loopInterval , order )
    --
--
--
--

    
    return self:callById( self.logicActionManagerId , "createAndAddAction" , actionType , datas , startFrameIdx , loopInterval , order )
end

function UBFGameBoardLogic:changeAllFSMState(stateKey)
    local runnableOrderList = self:getRunnableBoardIdList()
    for _, boardId in pairs(runnableOrderList) do
        self:callById(self.stateMachineIdMap[boardId], "changeState", stateKey)
    end
end

function UBFGameBoardLogic:changeFSMState(stateKey, boardId)
    self:callById(self.stateMachineIdMap[boardId or 1], "changeState", stateKey)
end

function UBFGameBoardLogic:getFSMState(boardId)
    return self:callById(self.stateMachineIdMap[boardId or 1], "getCurrStateKey")
end

function UBFGameBoardLogic:getFSMStateObject(stateKey, boardId)
    stateKey = stateKey or self:getFSMState()
    return self:callById(self.stateMachineIdMap[boardId or 1], "getState" , stateKey)
end

--------------------****** *↓* ******--------------------
--				        BTree部分
--------------------****** *↑* ******--------------------

local BTreeSeedKeyMap = {
    [UBFGameBTreeTriggerType.onGuide] = "treeGuide"
}

--运行行为树，返回树是否正常运行结束（并非树结果）
function UBFGameBoardLogic:runBTree( treeData )
    local trigger = treeData.trigger 

    local triggerHanlder = self:callById(self.btLaunchLogicId, "getBeforeRunHandler" , treeData)
        
    if not triggerHanlder then return nil end

    local boardId = treeData.boardId or 1
    local boardContext = self.levelContext:getBoardContext(boardId)
    local selfSet = { [UBFConst.ContextSelfType.kCurrGameBoard] = boardContext:getShieldedTable().cKey }

    local itemId = treeData.itemId 
    local itemRawData = treeData.item

    if itemId and not itemRawData then 
        itemRawData = boardContext:filterItemRawDataById( itemId )
        if not itemRawData then 
            boardContext:release()
            return nil
        end
    end

    local context = {
        itemType = treeData.itemType,
        boardContext = boardContext,
        selfSet = selfSet,
        params = {},
    }
    
    --如果有item
    if itemRawData then 
        context.itemRawData = itemRawData
        selfSet[UBFConst.ContextSelfType.kCurrItem] = itemRawData[UBF_TABLE_SHIELDED_KEY].cKey
        context.itemType = itemRawData.itemType
    end

    context.params.itemType = context.itemType

    --对应handler处理，注入params和selfSet参数，并返回所需要运行的行为树结构id
    --该函数还具备codeRunner的能力，个别情况下，需要写代码，不用行为树的时候可能会出现
    local treeStructId , dCode , dResult = triggerHanlder(treeData, context)

    if not treeStructId then
        boardContext:release()
        return dCode , dResult
    end

    local seed 

    if treeData.seed then seed = treeData.seed
    else
        local seedKey = BTreeSeedKeyMap[trigger] or "btree"
        seed = boardContext:nextSeed(seedKey)
    end

    local tree = self:callById(self.btLaunchLogicId, "createTree", treeStructId, seed)
    if not tree then return nil end

    tree:setTrigger( trigger , context.params , context.selfSet )

    -- 当^item存在sourceId时，设置^m指向对应mod的envData；否则清空^m，防止同一棵树复用时脏上下文残留
    local modEnvData = nil
    if itemRawData and itemRawData.sourceId then
        modEnvData = self.levelContext:getModSourceEnv(itemRawData.sourceId)
    end
    local contextManager = tree.contextManager
    if modEnvData then
        contextManager:setValue({ UBFConst.ContextType.kTreeMapContext, tree.treeId, "_modEnv" }, modEnvData)
        tree:setRunSelfKey(UBFConst.ContextSelfType.kModEnv, { UBFConst.ContextType.kTreeMapContext, tree.treeId, "_modEnv" })
    else
        contextManager:setValue({ UBFConst.ContextType.kTreeMapContext, tree.treeId, "_modEnv" }, nil)
        tree:setRunSelfKey(UBFConst.ContextSelfType.kModEnv, nil)
    end

    self:retainSendMessage()

    -- --
--

    --
--
--


    local runFin , err = self:callById(self.btLaunchLogicId, "runTree", boardContext, tree)

    --
--
--


    -- --
--


    self:liberateSendMessage()


    boardContext:release()

    if not runFin and err then  
        if UBFGameEnv:is(UBFGameEnvKey.AUTO_PLAY_AI_MODE) and err then UBFThrow(err) end
        return nil
    end

    return runFin , tree:getTreeResultData()
end


--------------------****** *↓* ******--------------------
--				         响应部分
--------------------****** *↑* ******--------------------

--当反馈交换失败
function UBFGameBoardLogic:onSwapMatchFail( matchFeedbackId  , failData )
    self:callById( self.operationLogicId , "onSwapMatchFail" , matchFeedbackId , failData )
end

--当棋盘任何元素发生变更，清理静态缓存
function UBFGameBoardLogic:onBoardElementChange( boardContext )
    self.swapProposeListCache = nil
    self.swapProposeListCacheForView = nil
end

--当走了一步
--todo 什么叫当走了一步？稳态走一步到掉落态是，那掉落态走一步呢？
function UBFGameBoardLogic:onTakeStep( boardId )

    self:leagueCall("onStep")

    local boardContext = self.levelContext:getBoardContext( boardId )

    self:callById(self.productItemLogicId, "statisticsItemCountInBoard")
    self:callById(self.productItemLogicId, "refreshRules", boardContext, UBFProduceTriggerEvent.kMoveStep)

    self.levelContext:createNewStepContext(self:leagueCall( "getRealMoveCount" ))
    
    local event = UBFGameEventBusLogic:getEvent(UBFGamePlayEventEnum.kMoveStep, { })
    UBFGameEventBusLogic:dispatch(self, boardContext, event)

    boardContext:release()
end

function UBFGameBoardLogic:onBoardEnterWaiting(boardContext)
    -- local move = self:leagueCall("getMoveCount")
    -- if move > 0 then self:markTakeSection( boardId ) end
    if boardContext:isMainBoard() then 
        self:leagueCall("onEnterWaiting")

        -- 更新fuuu曲线
        self:shadowTargetCall("onEnterWaiting",boardContext)
        -- 更新曲线进度数据
        self:callById(self.fuuuGraphLogicId, "onEnterWaiting" )
        -- 更新调节
        self:callById(self.levelDiffChangeLogicId, "onEnterWaiting", boardContext)

        --通知snapshot
        pcall(function() self:callById(self.snapshotLogicId, "catchStep") end)

        --
--

    end

    if self:isAllBoardInWaiting() then 
        if self:getGamePlayState() == UBFGamePlayState.kRun then 
            self:markTakeSection(UBFSectionType.kStep)
        end
    end
    
    UBFGamePlayTest:enterWaiting(self)
    
    boardContext:setValue( "refreshTimesInOnceFalling" , nil )
    local attackCache = boardContext:getValue("attackCache")
    attackCache.homologousAttackGroupMap = {}

    --低端机型棋盘稳定时gc一次
    if self.low_device and self.low_device.auto_collect then collectgarbage("collect") end

    -- if __WIN32 and testUseRealThread == false and isLocalDevelopMode then 
    --     self:callById(self.snapshotLogicId , "getStepState")
    -- end

end

function UBFGameBoardLogic:onBoardEnterFalling(boardContext)
    local boardId = boardContext:getBoardId()
    if self:leagueCall("popSwapMark") then self:onTakeStep(boardId) end

    boardContext:setValue("updateFallingOrderFlag", true)

    --
--

end

function UBFGameBoardLogic:onBoardEnterBonusTime( boardId )
    self:markTakeSection(UBFSectionType.kFast)

    UBFGamePlayTest:enterBonusTime(self)

    if self.snapshotLogicId then
		local snap = self:callById( self.snapshotLogicId , "getStepState" )
        self.levelContext:setValue("_enterBonusSnap",snap)
    end
    if self.snapshotLogic2024Id then
		local snap = self:callById( self.snapshotLogic2024Id , "getSnapData" )
        self.levelContext:setValue("_enterBonusSnap2024",snap)
    end

    --各种不同的bonus状态，如果不管，就会自动进入win
    local treedata = { 
        trigger = UBFGameBTreeTriggerType.onBonus, 
        boardId = boardId,
    }
    self:runBTree(treedata)

    self:leagueCall("onEnterBonusTime")

    local boardContext = self.levelContext:getBoardContext(boardId)

    self:callById( 
        self.btLaunchLogicId, "eventMark" , 
        boardContext, UBFGameBTreeTriggerType.onBoardStable, 
        UBFBTreeMarkKeyType.kBonusDetonate, nil, {}
    )

    boardContext:release()
    
    self:callById(self.btLaunchLogicId, "setLastOperationType", boardContext, nil)
    self:changeFSMState(UBFConst.BoardSMKey.kFalling, boardId)
end

--当数据被请求从视图端
function UBFGameBoardLogic:onDataRequiredFromView( dataKey , params )
    if dataKey == UBFGameRequireDataKey.kEvent then 
        local boardContext = self.levelContext:getBoardContext( 1 )
        local itemType = params.itemType
        local event = UBFGameEventBusLogic:getEvent( UBFGamePlayEventEnum.kRequireData , { params = params } )
        UBFGameEventBusLogic:dispatchTargetItemType( self , boardContext , itemType , event )
        boardContext:release()
        return event:getData()
    elseif dataKey == UBFGameRequireDataKey.kSwapProposeList then 
        return self:getBoardSwapProposeListForView(params) 
    elseif dataKey == UBFGameRequireDataKey.kSnap2024 then
        params = params or {}
        local boardId = params.boardId or 1
        local snap2024 = nil
        if self.snapshotLogic2024Id then
            snap2024 = self:callById(self.snapshotLogic2024Id, "getSnapData", { boardId = boardId })
        end

        local swapBorder = nil
        local boardContext = self.levelContext:getBoardContext(boardId)
        if boardContext then
            swapBorder = boardContext:getBoardBorder(true)
            boardContext:release()
        end

        return {
            snap2024 = snap2024,
            swapBorder = swapBorder,
        }
    elseif dataKey == UBFGameRequireDataKey.kFuuuInfo then 
        local deviation, resultMap = self:callById(self.fuuuGraphLogicId, "getFuuuDeviation", params.linearCheck , params.forceRecalc)
        local stepProgressDataList = self:callById(self.fuuuGraphLogicId, "getStepProgressDataList")
        return {deviation = deviation, resultMap = resultMap, stepProgressDataList = stepProgressDataList} 
    elseif dataKey == UBFGameRequireDataKey.kAIPlayHotspotControl then
        params = params or {}
        local function normalizeBool(value)
            if value == nil then return nil end
            if value == true or value == 1 or value == "1" or value == "true" then return true end
            if value == false or value == 0 or value == "0" or value == "false" then return false end
            return nil
        end

        local AIPlayHotspotCollector = require "ubf.UBFPlay.logics.ai.UBFAIPlayHotspotCollector"
        local enabled = normalizeBool(params.enabled)
        local reset = normalizeBool(params.reset)
        if reset then
            AIPlayHotspotCollector:reset(enabled)
        elseif enabled ~= nil then
            AIPlayHotspotCollector:setEnabled(enabled)
        end

        return {
            enabled = AIPlayHotspotCollector:isEnabled(),
            hotspot = AIPlayHotspotCollector:snapshot(),
        }
    elseif dataKey == UBFGameRequireDataKey.kFilterTargetProducers then 
        local tallyIds = params.tallyIds
        local boardContext = self.levelContext:getBoardContext(1)
        local list = {}
        for i, tallyId in ipairs(tallyIds) do
            list[tallyId] = UBFBoardItemHelper:filterTargetProducers(self, boardContext, tallyId)
        end
        return list
    elseif dataKey == UBFGameRequireDataKey.kLeagueSwapMixData then
        local league = self:leagueCall("getLeague")
        local data = {
            league = {
                itemMixMap = league and league.itemMixMap,
                itemSwapMap = league and league.itemSwapMap
            },
        }
        return data
    elseif dataKey == UBFGameRequireDataKey.kAdjustDebugInfo then
        local data = {}
        data.adjustData = self:callById(self.levelDiffChangeLogicId, "getAdjustData")
        data.adjustStepData = self:callById(self.levelDiffChangeLogicId, "getAdjustStepData")
        return data
    end
end

--当逻辑结束！
function UBFGameBoardLogic:onEndLevel()
    self:stopMainLoop()

    local boardContext = self.levelContext:getBoardContext()
    local gEnv = self.levelContext:getValue( UBFLevelContext.gameEnvKey )
    local UBFEndLevelData = require 'ubf.UBFPlay.data.UBFEndLevelData'
    local AIPlayHotspotCollector = require "ubf.UBFPlay.logics.ai.UBFAIPlayHotspotCollector"
    local endLevelData = UBFEndLevelData.new()
    endLevelData:fromLua({
        win = false,
        totalScore = self:leagueCall("getCurrScore"),
        star = self:leagueCall("getCurrStar"),
        endFrame = self:getCurrLogicFrameIndex(),
        seed = boardContext:getBoardSeed(),
        sourceResultMap = {},
        levelId = gEnv.levelId,
        levelType = gEnv.levelType,
        levelScene = gEnv.levelScene,
        moveCount = self:leagueCall("getMoveCount"),
        moveCountWithRevert = self:leagueCall("getRealMoveCount"),
        staticMoveCount = self:leagueCall("getStaticMoveCount"),
        dcData = self.levelContext:getValue( UBFLevelContext.dcDataKey ),
    })
    local playState = self:getGamePlayState()
    if playState == UBFGamePlayState.kWin then 
        endLevelData:setWin(true)
    else
        endLevelData:setWin(false)
        endLevelData:setFailReason(self:callById( self.judgeLogicId , "getFailReason" ))
    end

    local league = self:leagueCall("getLeague")
    league.aiPlayHotspot = AIPlayHotspotCollector:snapshot()
    league.onceFallingData = nil
    endLevelData:setLeague(league)
    endLevelData.data.aiPlayHotspot = league.aiPlayHotspot

    endLevelData:setStepProgressDataList( self:callById( self.fuuuGraphLogicId , "getStepProgressDataList" ) )

    local event = UBFGameEventBusLogic:getEvent( UBFGamePlayEventEnum.kEndLevel , {
        data = endLevelData.data,
        obj = endLevelData,
    } )
    UBFGameEventBusLogic:dispatch( self , boardContext , event )

    boardContext:release()
    
    self:sendToAgent( UBFPlayEventType.kEnd , endLevelData.data ) 
end

function UBFGameBoardLogic:onAgentedMessage( id , agented , ... )
    local event = select(1, ...)
	if event == UBFStateMachine.Events.kStateChange then 

        local newState = select(2, ...)
        local oldState = select(3, ...)

        local boardContext = self.levelContext:getBoardContext(agented.boardId)

        if oldState == UBFConst.BoardSMKey.kWating and newState == UBFConst.BoardSMKey.kFalling then 
            self:onBoardEnterFalling(boardContext)
        elseif newState == UBFConst.BoardSMKey.kWating then
            self:onBoardEnterWaiting(boardContext)
        end 

        self:sendBoardStateChange(agented.boardId, UBFBoardStateKey.kSMKey, newState) --发送状态机变化

        local event = UBFGameEventBusLogic:getEvent(UBFGamePlayEventEnum.kSMStateChange, {
            newState = newState,
            oldState = oldState,
        })
        UBFGameEventBusLogic:dispatch(self, boardContext, event)

        boardContext:release()

    elseif event == UBFPlayEventType.kGamePlayStateChange then 
        -- rust change_game_play_state
        local newState = select( 2 , ... )
        local oldState = select( 3 , ... )
        local extra = select( 4 , ... )
        local boardId = 1 

        local extra = extra or {}
        local boardContext = self.levelContext:getBoardContext( boardId )
        local packet = {
            newState = newState,
            oldState = oldState,
            sendExtra = extra,
            takeOver = false,
        }
        local event = UBFGameEventBusLogic:getEvent(UBFGamePlayEventEnum.kGameStateChange, packet)
        UBFGameEventBusLogic:dispatch(self, boardContext, event)
        boardContext:release()

        --被某个moudle托管了，你加油
        if packet.takeOver then return end

        if newState ~= UBFGamePlayState.kRun then self:sendBoardStateChange(boardId, UBFBoardStateKey.kCanSwap , false )
        else self:sendBoardStateChange(boardId, UBFBoardStateKey.kCanSwap, true) end

        --发送变化
        self:sendGamePlayStateChange(newState, extra)

        --处理
        if newState == UBFGamePlayState.kFail or newState == UBFGamePlayState.kWin then self:onEndLevel() 
        elseif newState == UBFGamePlayState.kAlmostWin then
            self:onBoardEnterBonusTime(boardId) 
            self:callById(self.productItemLogicId, "refreshRules", boardContext, UBFProduceTriggerEvent.kEnterAlmostWin)
        end
    end
end

--------------------****** *↓* ******--------------------
--				         大棋盘
--------------------****** *↑* ******--------------------

function UBFGameBoardLogic:doChangeBoardBorder(boardContext, gridPos, size)
    local hasChange, changeData = boardContext:setBoardViewport(gridPos.r, gridPos.c, size.width, size.height)
    if not hasChange then return false end

    self:callById(self.fallingItemLogicId , "updateFallingOrderRandomList", boardContext, boardContext:nextSeed("falling"))

    local event = UBFGameEventBusLogic:getEvent(UBFGamePlayEventEnum.kChangeViewBorder, { 
        oldBorder = changeData.oldBorder and table.clone(changeData.oldBorder), 
        newBorder = changeData.newBorder and table.clone(changeData.newBorder),
        newRectList = changeData.newRectList and table.clone(changeData.newRectList),
    })
    UBFGameEventBusLogic:dispatch(self, boardContext, event)
    
    return true, changeData
end

function UBFGameBoardLogic:doSendChangeMessage(boardContext, changeData, frameLength)
    local currLogicFrameIndex = self:getCurrLogicFrameIndex()
    local buildData = self:createGameBoardViewBuildExpandMessage(1, changeData.newRectList) 
    buildData.frames = frameLength
    self.messageManager:sendMessages(buildData)
end

function UBFGameBoardLogic:doChangeBoardAfter(boardContext, changeData, frameLength)
    local currLogicFrameIndex = self:getCurrLogicFrameIndex()
    local checkPosList = {}
    UBFBigBoardHelper:ergodicRectList(changeData.newRectList, function(r, c)
        table.insert(checkPosList, { r = r , c = c})
    end)
    UBFBoardItemHelper:createCheckMatch(
        self, checkPosList, boardContext:getValue("boardId"), 
        currLogicFrameIndex + frameLength + 1, 
        "boardChange"
    )
end

function UBFGameBoardLogic:changeAllBoardBorderWithMainBoard(gridPos, size)
    local mainBoardId = 1
    local mainBoardContext = self.levelContext:getBoardContext(mainBoardId)
    --先尝试更新主
    local hasChange, changeData = self:doChangeBoardBorder(mainBoardContext, gridPos, size)
    if not hasChange then 
        mainBoardContext:release()
        return false
    end
    --生成board变更数据
    local changeBoardResult = {}
    changeBoardResult[mainBoardId] = changeData
    --跟新所有次board
    for id , boardContextRaw in pairs(self.levelContext:getBoardRawDataMap()) do 
        if id ~= mainBoardId then 
            local boardContext = UBFContextManager:pack(boardContextRaw)
            local hasChange, changeData = self:doChangeBoardBorder(boardContext, gridPos, size)
            if hasChange then changeBoardResult[id] = changeData end
            boardContext:release()
        end
    end
    --定义持续时间长度
    local frameLength = 60
    --发送视图
    self:doSendChangeMessage(mainBoardContext, changeData, frameLength)
    --更新主board其他内容
    self:doChangeBoardAfter(mainBoardContext, changeData, frameLength)
    --释放
    mainBoardContext:release()
    --切换状态
    self:changeFSMState(UBFConst.BoardSMKey.kFalling, 1)
    --发送action
    local currLogicFrameIndex = self:getCurrLogicFrameIndex()
    self:createAndAddLogicAction(UBFLogicActionType.kViewBorderChange, {}, currLogicFrameIndex + frameLength)
    --返回主board结果
    return true, changeBoardResult
end

--------------------****** *↓* ******--------------------
--				    序列反序列与断面
--------------------****** *↑* ******--------------------

--断面恢复和断面记录都是不允许在tick过程中进行的！！！
function UBFGameBoardLogic:markTakeSection(sectionType, isPoint, extra)
    self.takeSectionFlag = sectionType
    self.takeSectionFlagPoint = isPoint
    self.takeSectionExtra = extra
    --
--

end 

function UBFGameBoardLogic:clearMakeSectionMark()
    self.takeSectionFlag = nil
    self.takeSectionFlagPoint = nil
    self.takeSectionExtra = nil
end

--断面恢复和断面记录都是不允许在tick过程中进行的！！！
function UBFGameBoardLogic:markResumeSection(id, roadsOfDestiny)
    if self.resumeSectionFlag then 
        if _G.isLocalDevelopMode then UBFThrow "重复的断面恢复" end
        return 
    end
    self.resumeSectionFlag = id
    self.roadsOfDestiny = roadsOfDestiny
end 

function UBFGameBoardLogic:doTakeSection( flagType , isPoint )
    local extra = self.takeSectionExtra or {}
    if flagType == UBFSectionType.kStep then 
        extra.stepCount = self:leagueCall("getMoveCount")
        self:sendToAgent(UBFPlayEventType.kTakeSection, extra)
    else 
        self:sendToAgent( UBFPlayEventType.kTakeSection, extra, isPoint) 
    end
end 

--序列化，不报错contextmgr的内容
function UBFGameBoardLogic:serializeData()
    local dat = {
        actionMgr =  self:callById( self.logicActionManagerId , "serializeData" ),
        btlData = self:callById( self.btLaunchLogicId , "serializeData" ),
    }
    dat.fsmMap = {}
    for boardId, id in pairs(self.stateMachineIdMap) do 
        dat.fsmMap[boardId] = self:callById(id, "serializeData")
    end
    return dat
end

--反序列化，不报错contextmgr的内容
function UBFGameBoardLogic:deserializeData(dat)
    self:callById( self.logicActionManagerId , "deserializeData" , dat.actionMgr )
    self:callById( self.btLaunchLogicId , "deserializeData" ,  dat.btlData )
    self:removeAllStateMachine()
    for boardId, fsmData in pairs(dat.fsmMap) do 
        self:buildStateMachineByBoardId(boardId)
        self:callById(self.stateMachineIdMap[boardId], "deserializeData", fsmData)
    end
end

-- extraData 里包含一些恢复信息，比如说是否后退一步
function UBFGameBoardLogic:createSectionResumeExtraData( resumeType )

    local boardContext = self.levelContext:getBoardContext( 1 )
    if not boardContext then return end

    local extra = {
        seedMap = boardContext:getValue("boardSeedCurrMap"),
        resumedFrame = self:getCurrLogicFrameIndex()
    }

    boardContext:release()

    return extra
end

--断面恢复数据完成后，一些动态数据重新更新出来
function UBFGameBoardLogic:onSectionResumed( resumeType , extraData , oldLevelContext )

    local boardContextMap = {}
    for id , boardContextRaw in pairs(self.levelContext:getBoardRawDataMap()) do 
        boardContextMap[id] = UBFContextManager:pack(boardContextRaw)
    end

    for _ , singleBoardContext in pairs(boardContextMap) do 
        singleBoardContext:shieldedTableRefresh() 
        self:onBoardElementChange(singleBoardContext)
    end

    local boardContext = boardContextMap[1]
    
    if resumeType == UBFResumeType.kBackStep then 
        if extraData then 
            if extraData.seedMap then boardContext:setValue( "boardSeedCurrMap" , extraData.seedMap ) end
        end
        self:callById(self.btLaunchLogicId, "setLastOperationType", boardContext, UBFOperationType.kProp)
    end

    for _ , singleBoardContext in pairs(boardContextMap) do 
        singleBoardContext:release()
    end

    self:leagueCall("onSectionResumed", resumeType, oldLevelContext)

    local event = UBFGameEventBusLogic:getEvent( UBFGamePlayEventEnum.kSectionResumed, { 
        oldLevelContext = oldLevelContext, 
        extraData = extraData,
        resumeType = resumeType,
    } )
    UBFGameEventBusLogic:dispatch(self, boardContext, event)
end

function UBFGameBoardLogic:onSectionResumedFinish(resumeType, extraData, isSendInit)

    local isStep = resumeType == UBFResumeType.kBackStep

    if isSendInit and extraData then
        local boardIds = self.levelContext:getMutilBoardOrderList("viewLaunch") or self:getRunnableBoardIdList() or { 1 }
        
        local initMap = {}
        for _, boardId in ipairs(boardIds) do 
            if not initMap[boardId] then 
                initMap[boardId] = self:createGameBoardViewBuildInitMessage(boardId)
                if isStep then initMap[boardId].currStateMap[UBFBoardStateKey.kCanSwap] = false end
                initMap[boardId].resumedFrame = extraData.resumedFrame
            end
        end
        
        self.messageManager:sendMessages({
            mType = UBFGameMessageType.kBuildView, 
            mode = "init",
            initMap = initMap,
        })
    end

    if isStep then 
        local currLogicFrameIndex = self:getCurrLogicFrameIndex()
        self:createAndAddLogicAction(UBFLogicActionType.kEmpty, {}, currLogicFrameIndex + 60 * 2)
        self:changeAllFSMState(UBFConst.BoardSMKey.kFalling)
        self:markTakeSection(UBFSectionType.kFast, true)
    else
        self:buildDiffChangeLogic() 
    end

end

--------------------****** *↓* ******--------------------
--				        发送到视图层
--------------------****** *↑* ******--------------------

function UBFGameBoardLogic:retainSendMessage()
    self.messageManager:retain()
end

function UBFGameBoardLogic:liberateSendMessage()
    self.messageManager:liberate()
end

function UBFGameBoardLogic:sendViewAction( actionType , datas , startFrameIdx , frameLength )
    if (not startFrameIdx) or startFrameIdx == 0 then
        startFrameIdx = self:getCurrLogicFrameIndex()
    end
    local act = UBFViewActionData:create( actionType , datas , self:getCurrLogicFrameIndex() , frameLength )
    local datas = {
        mType = UBFGameMessageType.kViewAction ,
        action = act ,
    }

    --
--


    return self.messageManager:sendMessages( datas )
end

function UBFGameBoardLogic:sendViewActionList( actionList )
    local datas = {
        mType = UBFGameMessageType.kViewActionList ,
        actionList = actionList ,
    }
    --
--
--
--
--
--

    return self.messageManager:sendMessages( datas )
end

--发送棋盘的各种状态变化
function UBFGameBoardLogic:sendBoardStateChange( boardId , stateKey , stateValue )
    self.messageManager:sendMessages( {
        mType = UBFGameMessageType.kStateChange ,
        startFrameIdx = self:getCurrLogicFrameIndex(),
        key = stateKey,
        val = stateValue,
        boardId = boardId,
    } )
end

function UBFGameBoardLogic:sendGamePlayStateChange(gamePlayState, extra)
    extra = extra or {}
    if gamePlayState == UBFGamePlayState.kAlmostFail then 
        -- 传递给加五步面板的一些逻辑端数据
        -- fuuu曲线数据
        local progressData, isMeet = self:callById(self.fuuuGraphLogicId, "getFuuuProgressInFuuuStatus")
        -- printx(16,tts(progressData ),isMeet,"----------------")
        if isMeet then extra.fuuuProgressData = progressData end
        local _, fuuuDeviationResult = self:callById(self.fuuuGraphLogicId, "getFuuuDeviation", true, false)
        extra.fuuuDeviationResult = fuuuDeviationResult
        extra.dcData = self.levelContext:getValue(UBFLevelContext.dcDataKey)
        -- 加五步面板要用的数据（其实上面的fuuuDeviationResult也是，不过先不改了）
        local addStepPanelExtra = {}
        local dcData = extra.dcData
        if dcData and dcData.UBFuuu then
            local concernedDcData = {
                dmoveN0 = dcData.UBFuuu.maxDiffMoveOnStepN0,
                dmoveN3 = dcData.UBFuuu.maxDiffMoveOnStepN3,
            }
            addStepPanelExtra["concernedDcData"] = concernedDcData
        end
        local leagueContext = self.levelContext:getValue(UBFConst.ContextType.kLeagueContext)
        if leagueContext then
            local addStepSource = leagueContext.addStepSource
            if addStepSource then
                local preAddSteps = addStepSource.bySourceMap[UBFModSourceIdEnum.kPreProp] or 0
                addStepPanelExtra["preAddStepsVal"] = preAddSteps
            end
            addStepPanelExtra["addMoveCount"] = leagueContext.addMoveCount or 0
        end
        extra["addStepPanelExtra"] = addStepPanelExtra
    end
    self.messageManager:sendMessages( {
        mType = UBFGameMessageType.kGamePlayStateChange ,
        referBoardId = 1,   --参考的boardId，配合startFrameIdx让视图知道还要多少帧后展示
        startFrameIdx = self:getCurrLogicFrameIndex(),
        state = gamePlayState,
        datas = extra
    } )
end

--uiaction 除了棋盘之外的所有，与UBFGamePlayScene交互，而非BoardViewLogic
--ui操作保持原子性，且时序不敏感，最次情况按顺序运行就ok
function UBFGameBoardLogic:sendUIAction( actionType , datas , boardId , startFrameIdx )
    if (not startFrameIdx) or startFrameIdx == 0 then
        startFrameIdx = self:getCurrLogicFrameIndex()
    end
    local act = UBFUIActionData:create( actionType , datas , boardId , startFrameIdx )
    local datas = {
        mType = UBFGameMessageType.kUIAction ,
        action = act ,
    }
    return self.messageManager:sendMessages( datas )
end

function UBFGameBoardLogic:sendUIActionList( actionList )
    local datas = {
        mType = UBFGameMessageType.kUIActionList ,
        actionList = actionList ,
    }
    return self.messageManager:sendMessages( datas )
end


--------------------****** *↓* ******--------------------
--				  棋盘创建&更新发送消息创建部分
--------------------****** *↑* ******--------------------

--获取游戏启动数据，最前方的数据
function UBFGameBoardLogic:getGameInitData()
    local initData = {}

    local targetMap = self:callById(self.leagueLogicId, "getTargetMap")
    initData.targets = UBFHelper:toList(targetMap, function(v, k) 
        return { tallyId = k, count = v.expect } 
    end)

    return initData
end

function UBFGameBoardLogic:_createGameBoardViewBuildCommonMessage( boardContext , mode )
    local data = { mType = UBFGameMessageType.kBuildView , mode = mode }
    local boardBorder = boardContext:getValue( "boardBorder" )
    local boardSize = boardContext:getValue( "boardSize" )

    local width = boardBorder.right - boardBorder.left + 1
    local height = boardBorder.bottom - boardBorder.top + 1

    --视口，目前默认是1 ,1
    local sPos = { r = boardBorder.top , c = boardBorder.left }
    local size = { width = width, height = height }
    local viewport = { 
        left = sPos.c , 
        top = sPos.r ,
        right = sPos.c + size.width - 1 ,
        bottom = sPos.r + size.height - 1
    }
    --基于视口的坐标map
    local boardDataMap = {}

    local boardId = boardContext:getValue( "boardId" )
    --赋值
    data.boardSize = boardSize
    data.viewport = viewport
    data.size = size
    data.boardDataMap = boardDataMap
    data.boardId = boardId
    data.currFrame = self:getCurrLogicFrameIndex( boardId )
    
    local multiBoardInfo = boardContext:getValue("multiBoardInfo")
    data.multiBoardInfo = { logicScale = multiBoardInfo.logicScale }
    if multiBoardInfo.helpData then
        data.multiBoardInfo.mapGridPos = multiBoardInfo.helpData.mapGridPos
        data.multiBoardInfo.border = multiBoardInfo.helpData.border
    end

    return data
end

function UBFGameBoardLogic:_setGameBoardViewBoardData( boardContext , r , c , boardDataMap , d )
    local gridContext = boardContext:getGridContextByPos( r , c , d )
    if not gridContext then return end
    local isUsed = gridContext:getValue( "isUsed" )
    if isUsed then 
        if not boardDataMap[r] then boardDataMap[r] = {} end
        if not boardDataMap[r][c] then 
            boardDataMap[r][c] = {
                items = {},
                dimensionMap = {}
            } 
        end
        boardDataMap[r][c].dimensionMap[d or 0] = true 
        local items = gridContext:getItemList()
        local list = boardDataMap[r][c].items
        for k , v in ipairs( items ) do 
            local item = UBFContextManager:pack(v)
            local info = item:getViewInfo()
            if info then table.insert( list , info ) end
            item:release()
        end
    end
    gridContext:release()
end

function UBFGameBoardLogic:createGameBoardViewBuildInitMessage(boardId, allBorder)
    local boardContext = self.levelContext:getBoardContext(boardId)
    if not boardContext then return nil end
    
    local boardMap = boardContext:getBoardMap()

    local data = self:_createGameBoardViewBuildCommonMessage( boardContext , "init" )

    local boardBorder = data.viewport
    data.boardBorder = boardBorder

    if allBorder then 
        local allBorder = {
            top = 1,
            left = 1,
            right = data.boardSize.width,
            bottom = data.boardSize.height,
            realBottom = data.boardSize.realheight,
        }
        boardBorder = allBorder
        data.boardBorder = boardBorder
        data.showViewport = allBorder
    end

    data.currStateMap = {
        [UBFBoardStateKey.kSMKey] = self:callById(self.stateMachineIdMap[boardId], "getCurrStateKey" ),
        [UBFBoardStateKey.kCanSwap] = false,
    }

    local boardDataMap = data.boardDataMap
    
    for r = boardBorder.top , boardBorder.bottom do 
        for c = boardBorder.left , boardBorder.right do 
            self:_setGameBoardViewBoardData( boardContext , r , c , boardDataMap )
        end
    end

    for r = boardBorder.top , boardBorder.bottom + 1 do 
        for c = boardBorder.left , boardBorder.right + 1 do 
            self:_setGameBoardViewBoardData( boardContext , r , c , boardDataMap , 1 )
        end
    end

    self:_setGameBoardViewBoardData( boardContext , 0 , 0 , boardDataMap )
    
    --
--
--
--
--
--
--


    boardContext:release()

    return data
end

function UBFGameBoardLogic:createGameBoardViewBuildExpandMessage( boardId , rectList )
    local boardContext = self.levelContext:getBoardContext( boardId )
    local boardMap = boardContext:getBoardMap()

    local data = self:_createGameBoardViewBuildCommonMessage( boardContext , "expand" )

    local boardDataMap = data.boardDataMap
    data.rectList = rectList

    for k , rect in ipairs( rectList ) do 
        UBFBigBoardHelper:ergodicRect( rect , function( r , c )
            self:_setGameBoardViewBoardData( boardContext , r , c , boardDataMap )
        end ) 
        UBFBigBoardHelper:ergodicRect( rect , function( r , c )
            self:_setGameBoardViewBoardData( boardContext , r , c , boardDataMap , 1 )
        end , 1 ) 
    end

    boardContext:release()

    return data
end

--------------------****** *↓* ******--------------------
--				       棋盘调试模块
--------------------****** *↑* ******--------------------

function UBFGameBoardLogic:isDebugEnabled( key )
    --
--
--
--
--

    return false
end

function UBFGameBoardLogic:setDebugEnabled( key , dataSetOrBoolean )
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

end

function UBFGameBoardLogic:getDebugDataSet( key )
    --
--

end

function UBFGameBoardLogic:callDebugDataSetInst( key , funcName , ... )
    --
--
--

end

function UBFGameBoardLogic:sendDebugMessage( msgkey , data )
    self.messageManager:sendMessages( {
        mType = UBFGameMessageType.kDebugClickInst,
        boardId = 1,
        key = msgkey,
        datas = data,
    } )
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
--
--
--
--
--
--
--
--

