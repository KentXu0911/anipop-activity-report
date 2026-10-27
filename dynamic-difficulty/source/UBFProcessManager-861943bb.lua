UBFProcessManager = {}

local function buildBridgeError(code, message, details)
    return {
        code = code,
        message = message,
        details = details or {},
    }
end

local function validateProcessCmd(cmd, params, currProcess)
    if not currProcess then
        UBFLogN("Ignore process cmd", cmd, "current process not found", params)
        return false
    end
    if type(params) ~= "table" then
        return false, buildBridgeError(UBFAmfBridge.ErrorCode.INVALID_PARAMS, "params must be table")
    end
    local processId = params.processId
    if processId == nil then
        return false, buildBridgeError(UBFAmfBridge.ErrorCode.INVALID_PARAMS, "params.processId is required")
    end
    local currentProcessId = currProcess:getProcessId()
    if processId ~= currentProcessId then
        UBFLogN("Ignore process cmd", cmd, "processId does not match, request", processId, "current", currentProcessId, params)
        return false
    end

    return true
end

---------------------------------------------------------------------------------------------
--                              ..*.* 外部接口 *.*..
---------------------------------------------------------------------------------------------

-- static
function UBFProcessManager:showResourceLoadFailMessage()
    CommonTip:showTip("资源加载失败，点击关卡花重新加载吧~")
end

function UBFProcessManager:launch(enum, launchData)
	require("ubf.UBF.utils.UBFCommonRequire")("*")
    if self[enum] then 
        return self[enum](self, launchData)
    elseif launchData.isLaunchEndLevelProcess then
        return self:_launchEndLevelProcess(enum, launchData)
    end
end

function UBFProcessManager:getCurrStartProcess()
    return self.currStartProcess
end

function UBFProcessManager:getCurrEndProcess()
    return self.currEndProcess
end

function UBFProcessManager:clearCurrStartProcess()
   self:_clearCurrStartProcess()
end

function UBFProcessManager:clearCurrEndProcess()
   self:_clearCurrEndProcess()
end

function UBFProcessManager:registerBridgeCmd()
    if _G.AutoPlayEnv then return end

    UBFAmfBridge:registerUbfCmd(UBFCmd.UPDATE_SL_DATA, function(params)
        local currProcess = self:getCurrStartProcess()
        local valid, error = validateProcessCmd(UBFCmd.UPDATE_SL_DATA, params, currProcess)
        if not valid then
            return nil, error
        end

        local runtime = currProcess:getResult("runtime")
        UBFProcessAmfDataHelper:updateStartLevelData(runtime, params)
        return
    end)

    UBFAmfBridge:registerUbfCmd(UBFCmd.UPDATE_EL_DATA, function(params)
        local currProcess = self:getCurrEndProcess()
        local valid, error = validateProcessCmd(UBFCmd.UPDATE_EL_DATA, params, currProcess)
        if not valid then
            return nil, error
        end

        local runtime = currProcess:getResult("runtime")
        UBFProcessAmfDataHelper:updateEndLevelData(runtime, params)
        return
    end)
end

function UBFProcessManager:_setCurrStartProcess(process)
    self.currStartProcess = process 
    if not process then return end
    local function dispose()
        if self.currStartProcess == process then
            self.currStartProcess = nil
            UBFCachedFile:clearCache()
        end
    end
    process:afterEnd():next(dispose)
    process:afterAbort():next(dispose)
end

UBFProcessManager:registerBridgeCmd()

function UBFProcessManager:_clearCurrStartProcess()
    if self.currStartProcess then
        if self.currStartProcess:isFinished() or self.currStartProcess:isAborted() then 
            self.currStartProcess = nil
        else
            self.currStartProcess:abort()
            self.currStartProcess = nil
        end
    end
end

function UBFProcessManager:_setCurrEndProcess(process)
    self.currEndProcess = process 
    if not process then return end
    local function dispose()
        if self.currEndProcess == process then
            self.currEndProcess = nil
            UBFCachedFile:clearCache()
        end
    end
    process:afterEnd():next(dispose)
    process:afterAbort():next(dispose)
end

function UBFProcessManager:_clearCurrEndProcess()
    if self.currEndProcess then
        if self.currEndProcess:isFinished() or self.currEndProcess:isAborted() then 
            self.currEndProcess = nil
        else
            self.currEndProcess:abort()
            self.currEndProcess = nil
        end
    end
end

--start level process
function UBFProcessManager:_doStartRun(launchData, processCreator, runtimeCreator)
	-- 正常启动进关流程时需要检查当前是否存在未完成的出关流程的,skipEndProcessCheck为true时跳过该检查
    if not launchData.skipEndProcessCheck and self.currEndProcess then
        local msg = "[UBFProcessManager] Cannot start level process: unfinished end-level process exists!"
        if EnvUtil:isDevelopMode() then
            UBFLogE(msg) 
            CommonTip:showTip(msg)
        else
            he_log_error(msg)
        end
    end
    -- 同一时间只能有一个进关process运行，当已有process未完成时，拒绝开启新的process
    local process = processCreator()
    if self.currStartProcess then
        if not launchData.forceLaunchNew then
            -- UBFDevAlert("同一时间只能有一个进关process运行，当前有process未完成时，拒绝开启新的process")
            process:abort()
            return process
        end
    end

    UBFCachedFile:clearCache()
    self:_clearCurrStartProcess()
    self:_setCurrStartProcess(process)

    local levelId = launchData.levelId
    local levelScene = launchData.levelScene

    local function nextStep(data)
        UBFPerfMonitor.mark("OpenSlp", "SuperBaseResEnd")
        if process ~= self:getCurrStartProcess() then return end
        if not data.success then 
            UBFProcessManager:showResourceLoadFailMessage()
            self:_clearCurrStartProcess()
            process:abort()
            return
        end
        local runtime = runtimeCreator()
        if launchData.startSource then runtime.startSource = launchData.startSource end
        process:setResult("runtime", runtime)
        if launchData.hook then launchData.hook(process) end
        process:start()
    end

    UBFPerfMonitor.mark("OpenSlp", "SuperBaseResStart")
    if launchData.editorMode then self:_prepareSuperBaseResourceForEditor(launchData.levelCfg):next(nextStep)
    else UBFGameSceneResourceMgr:prepareSuperBaseResource(levelId, levelScene):next(nextStep) end

    return process
end

function UBFProcessManager:_normalStart(launchData)
    return self:_doStartRun(
        launchData, 
        function() 
            return UBFSLProcessFlowController:create(UBFSLProcessFlowController:getDefaultStartLevelProcessCreateData()) 
        end, 
        function()
            local ctx = self:__createPlayId()
            return UBFSLRuntime:create { 
                levelId = launchData.levelId, 
                levelScene = launchData.levelScene,
                startLevelType = launchData.startLevelType,
                playId = ctx.playId,
                startTime = ctx.startTime,
                editorMode = _G.editorMode,
                extra = launchData.extra,
                lastElRuntime = launchData.lastElRuntime,

                -- NOTE 这两纯粹为了兼容旧代码，新的代码别用了
                startSource = launchData.startSource,
                detailPanelParams = launchData.detailPanelParams,
            }
        end
    )
end

function UBFProcessManager:_manualStart(launchData)
    return self:_doStartRun( 
        launchData, 
        function() 
            return UBFSLProcessFlowController:create(UBFSLProcessFlowController:getManualStartLevelProcessCreateData()) 
        end, 
        function()
            assert((launchData.playId == nil) == (launchData.startTime == nil),
                "playId and startTime must be provided together")
            local ctx = launchData.playId and {
                playId = launchData.playId,
                startTime = launchData.startTime,
            } or self:__createPlayId()
            return UBFSLRuntime:create { 
                levelId = launchData.levelId, 
                levelScene = launchData.levelScene,
                startLevelType = launchData.startLevelType or UBFStartLevelType.kCommon,
                playId = ctx.playId,
                startTime = ctx.startTime,
                levelCfg = launchData.levelCfg,
                levelGroupInfo = launchData.levelGroupInfo,
                forceLuaGameLogic = launchData.forceLuaGameLogic,
                continuePlayMode = launchData.continuePlayMode,
                ai_actDataMap = launchData.ai_actDataMap,
                editorMode = _G.editorMode,
                extra = launchData.extra,
                lastElRuntime = launchData.lastElRuntime,

                -- NOTE 这两纯粹为了兼容旧代码，新的代码别用了
                startSource = launchData.startSource,
                detailPanelParams = launchData.detailPanelParams,
            }
        end
    )
end

function UBFProcessManager:_retryStart(launchData)
    return self:_doStartRun( 
        launchData, 
        function() 
            return UBFSLProcessFlowController:create(UBFSLProcessFlowController:getRetryStartLevelProcessCreateData()) 
        end, 
        function()
            local ctx = self:__createPlayId()
            return UBFSLRuntime:create({ 
                levelId = launchData.levelId, 
                levelScene = launchData.levelScene,
                startLevelType = launchData.startLevelType or UBFStartLevelType.kCommon,
                playId = ctx.playId,
                startTime = ctx.startTime,
                editorMode = _G.editorMode,
                retryData = launchData.retryData,
                extra = launchData.extra,
                lastElRuntime = launchData.lastElRuntime,

                -- NOTE 这两纯粹为了兼容旧代码，新的代码别用了
                startSource = launchData.startSource,
                detailPanelParams = launchData.detailPanelParams,
            })
        end
    )
end

function UBFProcessManager:_resumeStart(launchData)
    local sectionData = launchData.sectionData
    local levelInfo = sectionData.levelInfo
    launchData.levelId = levelInfo.levelId
    launchData.levelScene = levelInfo.levelScene
    return self:_doStartRun( 
        launchData, 
        function() 
            return UBFSLProcessFlowController:create(UBFSLProcessFlowController:getResumeStartLevelProcessCreateData()) 
        end, 
        function()
            return UBFSLRuntime:create({ sectionData = launchData.sectionData })
        end
    )
end

function UBFProcessManager:_replayStart(launchData)
    local function doReplay(launchData)
        local oplog = launchData.wReplayLog or launchData.oplog
        local levelId = oplog.gEnv.levelId
        local levelScene = oplog.gEnv.levelScene or LevelScene.kDefault
        launchData.levelId = levelId
        launchData.levelScene = levelScene
        launchData.wReplayLog = oplog
        
        return self:_doStartRun( 
            launchData, 
            function() 
                return UBFSLProcessFlowController:create(UBFSLProcessFlowController:getWonderfulReplayLevelProcessCreateData()) 
            end, 
            function()
                return UBFSLRuntime:create({ 
                    levelId = launchData.levelId, 
                    levelScene = launchData.levelScene,
                    replayLog = launchData.wReplayLog,
                    wonderfulReplay = true,
                    extra = launchData.extra,
                    lastElRuntime = launchData.lastElRuntime,

                    -- NOTE 这两纯粹为了兼容旧代码，新的代码别用了
                    startSource = launchData.startSource,
                    detailPanelParams = launchData.detailPanelParams,
                })
            end
        )
    end
    if not launchData.oplogStr or not launchData.oplog then
        return doReplay(launchData)
    end

    local oplogStr = launchData.oplogStr
    local oplog = launchData.oplog or table.deserialize(launchData.oplogStr)
    return doReplay({
        wReplayLog = oplog,
    })
end

function UBFProcessManager:_debugReplayStart(launchData)
    local function doReplay(launchData)
        local oplog = launchData.wReplayLog or launchData.oplog
        local levelId = oplog.gEnv.levelId
        local levelScene = oplog.gEnv.levelScene or LevelScene.kDefault
        launchData.levelId = levelId
        launchData.levelScene = levelScene
        launchData.oplog = oplog
        launchData.levelCfg = oplog.levelCfg
		-- 跳过出关流程检查，正常启动进关流程时需要检查当前是否存在未完成的出关流程的。
		launchData.skipEndProcessCheck = true
        local result = self:_doStartRun( 
            launchData, 
            function() 
                return UBFSLProcessFlowController:create(UBFSLProcessFlowController:getDebugReplayLevelProcessCreateData()) 
            end, 
            function()
                return UBFSLRuntime:create({ 
                    levelId = launchData.levelId, 
                    levelScene = launchData.levelScene,
                    replayLog = launchData.oplog,
                    debugReplay = true,
                    extra = launchData.extra,
                    lastElRuntime = launchData.lastElRuntime,
                    levelCfg = launchData.levelCfg,

                    -- NOTE 这两纯粹为了兼容旧代码，新的代码别用了
                    startSource = launchData.startSource,
                    detailPanelParams = launchData.detailPanelParams,
                })
            end
        )
        return result
    end
    if not launchData.oplogStr or not launchData.oplog then
        return doReplay(launchData)
    end

    local oplogStr = launchData.oplogStr
    local oplog = launchData.oplog or table.deserialize(launchData.oplogStr)
    return doReplay({
        oplog = oplog,
    })
end

function UBFProcessManager:_editorStart(launchData)
    _G.editorMode = true
    launchData.editorMode = true
    return self:_doStartRun(
        launchData,
        function() return UBFSLProcessFlowController:create(UBFSLProcessFlowController:getEditorStartLevelProcessCreateData()) end, 
        function()
            local ctx = {
                startTime = os.time() + (__g_utcDiffSeconds or 0),
                playId = "SuperUBFEditor"
            }
            local slRuntime = UBFSLRuntime:create {
                levelId = launchData.levelId,
                levelScene = launchData.levelScene,
                startLevelType = launchData.startLevelType or UBFStartLevelType.kCommon,
                levelCfg = launchData.levelCfg,
                playId = ctx.playId,
                startTime = ctx.startTime,
                editorMode = true,
                randomSeed = launchData.randomSeed or ctx.startTime, -- 先随便来一个值
                extra =  launchData.extra,
            }

            -- 编辑器进关给SLRuntime填充fuuu数据
            local ubfuuuInfo = _G.lastEditorData and _G.lastEditorData.ubfuuu
            local fuuuGraph = nil
            if ubfuuuInfo and ubfuuuInfo.fuuuChartV3 then
                fuuuGraph = {}
                fuuuGraph.fuuuChartV3 = ubfuuuInfo.fuuuChartV3
                fuuuGraph.fuuuChartV3Info = ubfuuuInfo.fuuuChartV3Info
            end
            slRuntime:setFuuuGraphV3(fuuuGraph)

            return slRuntime
        end
    )
end

--创建PlayId from StartGamePanel2020Manager.getInstance():__createPlayId(self)
function UBFProcessManager:__createPlayId()
    local ctx = {}
	local uid =  UserManager:getInstance():getUID() or "12345"
	local udid = MetaInfo:getInstance():getUdid() or "noUdid"
	ctx.startTime = os.time() + (__g_utcDiffSeconds or 0)
	local list = {tostring(uid),tostring(udid),tostring(ctx.startTime)}
    ctx.playId = table.concat(list,"_")
	return ctx
end

--准备最最最最基础的资源 For Editor
function UBFProcessManager:_prepareSuperBaseResourceForEditor(levelCfg)
    local segment = UBFPromise:segment()
    local pCalc = UBFProgressCalculator:create()
    local rtable = { success = true }

    segment:retain()
    UBFResourceLoader.file:async("#gameplay_scene_before_must"):next(function(status)
        rtable.success = (status == UBResourceLoadStatus.READY) and rtable.success
        segment:release()
    end)
    pCalc:add(function() return UBFResourceLoader.file:progress("#gameplay_scene_before_must") end)

    segment:retain()
    local promise = UBFGameSceneResourceMgr:loadSuperBaseResource():next(function(status)
        rtable.success = (status == UBResourceLoadStatus.READY) and rtable.success
        segment:release()
    end)
    pCalc:add(function() return promise:getProgress() end, 10)

    segment:resolve(rtable)

    return segment
end

-- end level process
function UBFProcessManager:_launchEndLevelProcess(processType, runtime)
    local processCreateData = self:_getProcessCreateDataByType(runtime, processType)
	local process = UBFELProcessFlowController:create(processCreateData)
    -- 同一时间只能有一个出关process运行，当已有process未完成时，拒绝开启新的process
    if self.currEndProcess then
        UBFDevAlert("同一时间只能有一个出关process运行，当前有process未完成时，拒绝开启新的process")
        process:abort()
        return process
    end
    UBFCachedFile:clearCache()
    self:_clearCurrEndProcess(process)
    self:_setCurrEndProcess(process)
	self:_pushEndLevelProcess(process)
	setNextFrame(function() process:start() end)
    return process
end

function UBFProcessManager:_getProcessCreateDataByType(runtime, processType)
	local processCreateData
    lua_switch(processType){
        [UBFGameProcessEnum.CRASH] = function ( ... )
            processCreateData = UBFELProcessFlowController:getCrashProcessCreateData()
        end,
        [UBFGameProcessEnum.YUNGAME] = function ( ... )
            processCreateData = UBFELProcessFlowController:getYunGameEndLevelProcessCreateData()
        end,
        [UBFGameProcessEnum.WONDER_FULREPLAY] = function ( ... )
            processCreateData = UBFELProcessFlowController:getWonderfulEndLevelProcessCreateData()
        end,
        [UBFGameProcessEnum.AFH_PASS_LEVEL] = function ( ... )
            processCreateData = UBFELProcessFlowController:getAFHPassLevelProcessCreateData()
        end,
        [UBFGameProcessEnum.AFH_FAIL_LEVEL] = function ( ... )
            processCreateData = UBFELProcessFlowController:getAFHFailLevelProcessCreateData()
        end,
        [UBFGameProcessEnum.NORMAL_PASS_LEVEL] = function ( ... )
            processCreateData = UBFELProcessFlowController:getNormalPassLevelProcessCreateData()
        end,
        [UBFGameProcessEnum.ACTIVITY_DEPUTY_PASS_LEVEL] = function ( ... )
            processCreateData = UBFELProcessFlowController:getActivityDeputyPassLevelProcessCreateData()
        end,
        [UBFGameProcessEnum.NORMAL_FAIL_LEVEL] = function ( ... )
            processCreateData = UBFELProcessFlowController:getNormalFailLevelProcessCreateData()
        end,
        [UBFGameProcessEnum.QUIT_LEVEL] = function ( ... )
            processCreateData = UBFELProcessFlowController:getNormalQuitLevelProcessCreateData()
        end,
        [UBFGameProcessEnum.RETRY_LEVEL] = function ( ... )
            processCreateData = UBFELProcessFlowController:getRetryLevelProcessCreateData()
        end
    }
    if processCreateData then
        processCreateData.runtime = runtime
        processCreateData.gameProcessType = processType
    else
        UBFThrow("UBFProcessManager:没有找到对应的processCreateData, processType = " .. tostring(processType))
    end

	return processCreateData
end

function UBFProcessManager:_pushEndLevelProcess(procress)
    if not procress then return end
    local next 
    next = function()
        next = function() end
        local currStartProcess = self:getCurrStartProcess()
        UBFHelper:invoke(currStartProcess, "onEndLevelProcessFinish", procress)
    end
    procress:afterEnd():next(next)
    procress:afterAbort():next(next)
end

_G.UBFMigratorLaunch = function(data, startPanelCreator)
    if _G.isLocalDevelopMode then 
        if not data.levelScene then 
            UBFThrow("你启动关卡的levelScene呢？？？？？") 
        end
    end
    UBFProcessManager:launch(UBFGameProcessEnum.NORMAL_START, {
        levelId = data.levelId,
		startLevelType = data.startLevelType or StartLevelType.kCommon,
        levelScene = data.levelScene,

        extra = data.extra,

        -- NOTE 这两纯粹为了兼容旧代码，新的代码别用了
        startSource = data.startSource,
        detailPanelParams = data.detailPanelParams,

        hook = function(process)
			process._createOldStartPanel = startPanelCreator
		end,
    })
end

_G.UBFMigratorNoCompatibleLaunch = _G.UBFMigratorLaunch
