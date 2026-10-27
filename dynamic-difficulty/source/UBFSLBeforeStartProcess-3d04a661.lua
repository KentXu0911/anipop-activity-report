local UBFSLBeforeStartProcess = class2("UBFSLBeforeStartProcess", UBFProcessNode)

function UBFSLBeforeStartProcess:createSceneCtx(runtime, levelJsonData, levelInfo)
	UBFGameplaySceneLogicManager:ensureRegistered()
	local sceneCtx = UBFGameplaySceneLogicManager:createSceneCtx({
		levelInfo = levelInfo,
		levelJsonData = levelJsonData,
		isResumeMode = runtime:isResumeMode(),
		isInRust = runtime:isInRust(),
		isAIMode = runtime:isAIMode(),
		isReplayMode = runtime:isReplayMode(),
		isEditorMode = runtime:isEditorMode(),
		isDebugMode = runtime:isDebugMode(),
		sceneModuleCreateMap = self:get("sceneModuleCreateMap"),
		boardFeatureCreateMap = self:get("boardFeatureCreateMap"),
	})
	UBFGameplaySceneLogicManager:resolveActiveSceneLogics(sceneCtx)
	return sceneCtx
end

function UBFSLBeforeStartProcess:doProcess()
	-- @ UBFStartLevelLogic:_startUBFGame 虽然对应旧的这个流程，但是实际情况已经大变了
    local runtime = self:get("runtime")

	self:doPrepareConfig(runtime)
	self:doModifyConfig(runtime)

    self:success()
end

local function tryGetDiffFix(modMgr)
	local adjData = modMgr:getModData(UBFModSourceIdEnum.kDiffAdjustModMgr)
    adjData = adjData and adjData[1]
    adjData = adjData and adjData.env
    if not adjData then return end
    local adjustData = adjData.adjustData
    return adjustData and adjustData.diffFix
end

function UBFSLBeforeStartProcess:supplyLevelInfo(runtime, levelInfo)
	local modMgr = runtime:getModMgr()
	local energyMgr = runtime:getEnergyMgr()
    local levelJsonData = runtime:getLevelJsonData()

	--准备levelInfo
	local selectedItemsData = runtime:getOverallEventData(UBFGameModEventEnum.GET_DATA_SELECTED_ITEMS_DATA) or {}
	levelInfo.modList = self:get("replayModList") or modMgr:generateGamePlayModList()
	levelInfo.adjustData = runtime:getAdjustData()
	levelInfo.beginTime = Localhost:timeInMillis()
	levelInfo.costType = energyMgr.costType
	levelInfo.costEnergy = energyMgr.costEnergy
	levelInfo.useInfiniteEnergy = energyMgr.useInfiniteEnergy
	if runtime:isInRust() then 
		levelInfo.so_rust = runtime.so_rust or {} 
		levelInfo.so_prophet = runtime.rustProphetKey
		levelInfo.prophetLaunchInfo = runtime.prophetLaunchInfo
	end
	if _G.REPLAY_STAGE then
		levelInfo.enterEnergy = -1
		levelInfo.enterMaxEnergy = -1
		levelInfo.startLevelCostType = -1
	else
		levelInfo.enterEnergy = energyMgr:getCurrEnergy()
		levelInfo.enterMaxEnergy = energyMgr:getMaxEnergy()
		levelInfo.startLevelCostType = energyMgr:getStartLevelCostType()
	end
	levelInfo.playLevelMode = runtime.playLevelMode
	local willingModAllowList = runtime:getExtra("willingModAllowList")
	levelInfo.willingModAllowList = type(willingModAllowList) == "table"
		and UBFHelper:shallowClone(willingModAllowList) or nil
	levelInfo.playerStateSandbox = runtime:isPlayerStateSandbox()
	levelInfo.dcData = runtime:getDCData()
	levelInfo.outLevelAttachData = runtime.outLevelAttachData
	levelInfo.diffFix = tryGetDiffFix(modMgr)
	levelInfo.temp = {
		selectedItemsData = selectedItemsData,
	}

	if #selectedItemsData > 0 then 
		levelInfo.hasUsePreprop = true
	end

    levelInfo.stats = runtime:getAllStats()

	return levelInfo
end

function UBFSLBeforeStartProcess:doPrepareConfig(runtime)
	local modMgr = runtime:getModMgr()
	local energyMgr = runtime:getEnergyMgr()
    local levelJsonData = runtime:getLevelJsonData()
	
	--初始化levelinfo
	local levelInfo = self:get("levelInfo") 
	if not levelInfo.byResume then 
		self:supplyLevelInfo(runtime, levelInfo)
	end

	--创建场景module数据
	self._dev_debug_rumtime_ = runtime
    --
--

	local sceneModuleCreateMap = self:createSceneModuleDataMapUBFUi(runtime, levelJsonData, levelInfo)
	self:set("sceneModuleCreateMap", sceneModuleCreateMap)
    --
--


	local sceneUiCreateDelegate = self:createSceneUiCreateDelegate(runtime, levelJsonData, levelInfo)
	self:set("sceneUiCreateDelegate", sceneUiCreateDelegate)
    --
--


    --创建BoardViewLogic所有TileViewLogic的构建数据
    local featureManager = self:get("featureManager")
    local boardFeatureCreateMap = {}
	self:addCreateDataToBoardFeatureCreateMapByFeatureMap(
		boardFeatureCreateMap, 
		levelJsonData:getLevelFeatureMap(), 
		featureManager
	)
    self:set("boardFeatureCreateMap", boardFeatureCreateMap)

    local sceneCtx = self:createSceneCtx(runtime, levelJsonData, levelInfo)
    self:set("sceneCtx", sceneCtx)
end

function UBFSLBeforeStartProcess:doModifyConfig(runtime)
    local levelJsonData = runtime:getLevelJsonData()
    local levelInfo = self:get("levelInfo")
    local sceneModuleCreateMap = self:get("sceneModuleCreateMap")
    local boardFeatureCreateMap= self:get("boardFeatureCreateMap")
    local sceneCtx = self:get("sceneCtx")
    local resourceMgr = runtime:getSceneResourceMgr()

	UBFGameplaySceneLogicManager:dispatchLifecycle(sceneCtx, "onScenePrepare", self:get("sceneUiCreateDelegate"))

	local levelType = levelInfo.levelType or (levelJsonData and levelJsonData:getLevelType())
	local levelScene = levelInfo.levelScene

	resourceMgr:prepareLevelAudio(
		sceneCtx:getSceneBGM(),
		sceneCtx:getSceneSounds()
	)

    self:dispatchModEvent(UBFGameModEventEnum.MODIFY_ENTER_CONFIG, {
		boardFeatureCreateMap = boardFeatureCreateMap,
		sceneModuleCreateMap = sceneModuleCreateMap,
        levelType = levelType,
        levelScene = levelScene,
	})

end

function UBFSLBeforeStartProcess:doRevert()
	self:set("levelInfo", nil)
	self:set("sceneModuleCreateMap", nil)
	local sceneCtx = self:get("sceneCtx")
	if sceneCtx then
		UBFGameplaySceneLogicManager:destroySceneCtx(sceneCtx)
	end
	local uiCreateDelegate = self:get("sceneUiCreateDelegate")
	if uiCreateDelegate then
		uiCreateDelegate:clear()
	end
	self:set("sceneUiCreateDelegate", nil)
    self:set("boardFeatureCreateMap", nil)
	self:set("sceneCtx", nil)
end

function UBFSLBeforeStartProcess:createSceneModuleDataMapUBFUi(runtime, levelJsonData, levelInfo)
	local moduleMap = {}

	local function getOrCreateModule(moduleId, logicId)
		if moduleMap[moduleId] then return moduleMap[moduleId] end
		moduleMap[moduleId] = {
			logicId = logicId or moduleId,
			moduleId = moduleId,
			isUBFUi = true,
		}
		return moduleMap[moduleId]
	end

	--前景背景
	local bgfgModule = getOrCreateModule(UBFGameLogics.kBgFg)
	-- 为了兼容现存的BeforeConfigBuild事件，暂时保留一些数据结构
	UBFBgFgModule:initDefaultCreateDataForUBFUi(bgfgModule)

	--收集牌
	getOrCreateModule(UBFGameLogics.kTargetPad)
	moduleMap[UBFGameLogics.kTargetPad].targetPadSkinMap = {}

	--步数牌
	getOrCreateModule(UBFGameLogics.kStep)

	getOrCreateModule(UBFGameLogics.kFlyView)

	--分数条
	local scoreModule = getOrCreateModule(UBFGameLogics.kScore)
	scoreModule.scoreViewLogicBuildData = {
		scoreProgressViewData = {
			--树枝上活动收集物
			actCollectIcons = {},
			--树枝上活动挂件
			scorePendantData = {},
			--进度颜色混合组件
			scoreBarColorBlendData = {},
		}
	}
	scoreModule.isDisableView = false

	--游戏结束
	if runtime:isAIMode() then
		getOrCreateModule(UBFGameLogics.kEndGame, UBFGameLogics.kEndGameByAI)
	-- else
	-- 	getOrCreateModule(UBFGameLogics.kEndGame)
	end

	--mod管理
	local modModule = getOrCreateModule(UBFGameLogics.kGameMod)
	modModule.modList = levelInfo.modList

	--计数
	local tallyModule = getOrCreateModule(UBFGameLogics.kTally)
	tallyModule.tallyMap = {
		[UBFTallyId.kMoveStep] = {
			kind = UBFTallyKind.kCustom,
			value = levelJsonData:getStaticMoveCount(),
			targetValue = 0
		},
		[UBFTallyId.kScore] = {
			kind = UBFTallyKind.kCustom,
			targetValue = 0
		}
	}
	local levelTargets = levelJsonData:getLevelTargets()
	for k , v in ipairs(  levelTargets ) do
		if v.tallyId then
			tallyModule.tallyMap[v.tallyId] = {
				kind = UBFTallyKind.kTarget,
				targetValue = v.count,
				priority = -k
			}
			if UBFTestHasNewTargetIcon(v.tallyId) then
				local skin = moduleMap[UBFGameLogics.kTargetPad].targetPadSkinMap[v.tallyId]
				if not skin then skin = { viewData = {} } end
				moduleMap[UBFGameLogics.kTargetPad].targetPadSkinMap[v.tallyId] = skin
				skin.viewData.containerLayoutMode = "center"
				skin.viewData.containerScaleFix = 0.5
			end
		end
	end

	--道具栏
	local propBarModule = getOrCreateModule( UBFGameLogics.kPropBar )
	if runtime:isReplayMode() and not runtime:isReplayResume() and not runtime:isEditorMode() then
        if not EnvUtil:isMiniGame() then
		    UBFGamePlaySceneMess:initModuleDataAboutPropBarByReplayLog(propBarModule, levelJsonData, runtime:getReplayLog())
        end
	else
		UBFGamePlaySceneMess:initModuleDataAboutPropBar( propBarModule , levelJsonData , runtime:isDebugPlayMode(), runtime:isInRust())
	end

	--精彩回放
	if levelInfo.wonderfulReplay then
		getOrCreateModule(UBFGameLogics.kWonderfulReplay)
		bgfgModule.pauseButtonViewData = nil
	end

	--收集栏
	local collectionModule = getOrCreateModule( UBFGameLogics.kCollectionBar )
	collectionModule.iconList = {}

	--信息流
	local informationDesignModule = getOrCreateModule( UBFGameLogics.KInformationFlowDesign )
	informationDesignModule.buildData = UBFInformationFlowDesignModule:getDefaultCreateData()
	UBFGamePlaySceneMess:initModuleDataAboutInformationDesign( informationDesignModule , levelJsonData , levelInfo )

	-- 加五步面板数据，需要先加载模块哦，不然存储和闪退恢复就不能还原数据了
	getOrCreateModule(UBFGameLogics.kAddStepPanelFull)

	-- TODO GGSkin UBFUi定制，还剩个道具栏没迁UBFUi
	--
--
--
--
--
--


	return moduleMap
end

function UBFSLBeforeStartProcess:createSceneUiCreateDelegate(runtime, levelJsonData, levelInfo)
    -- 基础关卡数据，有需要的在这里添加
    local simpleLevelInfo = {
        levelId = levelInfo.levelId,
        levelScene = levelInfo.levelScene,
        difficultyFlag = levelInfo.levelFlag or levelJsonData:getLevelDifficultFlag(),
		scoreTargets = levelJsonData:getScoreTargets(),
		oldScore = levelInfo.oldScore or 0,
		oldStar = levelInfo.oldStar or 0,
		topLevelId = levelInfo.topLevelId,
		topLevelFailCount = levelInfo.topLevelFailCount,
		scoreRefIsNil = levelInfo.scoreRefIsNil,
		levelTargets = levelJsonData:getLevelTargets(),
		
    }
    -- 满星关卡库
    simpleLevelInfo.fsllInfo = UBFActHelper:getFsllInfo(runtime)

    local params = {
    	levelInfo = simpleLevelInfo,
		isResumeMode = runtime:isResumeMode(),
        isInRust = runtime:isInRust(),
        isAIMode = runtime:isAIMode(),
        isReplayMode = runtime:isReplayMode(),
        isEditorMode = runtime:isEditorMode(),
        isDebugMode = runtime:isDebugMode(),
    }

	local delegate = UBFGameplayUiHelper:createGameplayUiCreateDelegate(params)
	return delegate
end

-- static
function UBFSLBeforeStartProcess:addCreateDataToBoardFeatureCreateMapByFeatureMap(boardFeatureCreateMap, featureMap, featureManager)
    boardFeatureCreateMap[UBFGameItemType.kAnimal] = { logicId = UBFTileViewLogicType.kAnimal }
    boardFeatureCreateMap[UBFGameItemType.kMagicBird] = { logicId = UBFTileViewLogicType.kMagicBird }
    boardFeatureCreateMap[UBFGameItemType.kFirecracker] = { logicId = UBFTileViewLogicType.kFirecracker }
    boardFeatureCreateMap[UBFGameItemType.kBuffThrowItem] = { logicId = UBFTileViewLogicType.kBuffThrowItem }
    boardFeatureCreateMap[UBFGameItemType.kBuffAddStep] = { logicId = UBFTileViewLogicType.kBuffAddStep }
    boardFeatureCreateMap[UBFGameItemType.kBuffStarBottle] = { logicId = UBFTileViewLogicType.kBuffStarBottle }
    boardFeatureCreateMap[UBFGameItemType.kAddon] = featureManager:createFeatureData(UBFGameItemType.kAddon) or { logicId = UBFTileViewLogicType.kAddon }
    boardFeatureCreateMap[UBFGameItemType.kBody] = { logicId = UBFTileViewLogicType.kBody }
	boardFeatureCreateMap[UBFGameItemType.kBuffSuperMagicBird] = featureManager:createFeatureData(UBFGameItemType.kBuffSuperMagicBird)
	boardFeatureCreateMap[UBFGameItemType.kCallbackBooster] = featureManager:createFeatureData(UBFGameItemType.kCallbackBooster)
	boardFeatureCreateMap[UBFGameItemType.kCallbackBoosterV2] = featureManager:createFeatureData(UBFGameItemType.kCallbackBoosterV2)
	boardFeatureCreateMap[UBFGameItemType.kPetitPet] = featureManager:createFeatureData(UBFGameItemType.kPetitPet)
    
    --todo 活动的应该移动到mod里面，之前是这样写的，要迁移
    boardFeatureCreateMap[UBFGameItemType.kModMaceOnAnimal] = { logicId = UBFTileViewLogicType.kModMaceOnAnimal }
    boardFeatureCreateMap[UBFGameItemType.kModCrownOnAnimal] = { logicId = UBFTileViewLogicType.kModCrownOnAnimal }

	local function setItemTypeFeature(itemType)
		boardFeatureCreateMap[itemType] = featureManager:createFeatureData(itemType)
		if not boardFeatureCreateMap[itemType] then
			-- 旧模式
			boardFeatureCreateMap[itemType] = {
				logicId = "Tile" .. itemType,
				checkRepeat = true
			}
		end
	end

	local itemViewConfig = featureManager.itemViewConfig or require "ubf.UBFPlay.views.UBFItemViewConfig"
	for itemType, _ in pairs(featureMap) do
		setItemTypeFeature(itemType)
		local info = itemViewConfig[itemType]
		if info and info.linked then
			for _, linkedItemType in ipairs(info.linked) do
				if not boardFeatureCreateMap[linkedItemType] then
					setItemTypeFeature(linkedItemType)
				end
			end
		end
	end

    return boardFeatureCreateMap
end

return UBFSLBeforeStartProcess
