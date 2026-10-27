UBFSLRuntime = class2("UBFSLRuntime", UBFProcessRuntime)

UBFStartLevelType = {
	kCommon = 1,
	kAskForHelp = 2,
}

local function try_launch_lag_check()
    xpcall(function()
		if UBFPlaySwitch:isGameOftenLagPlatform() and not _G.UBF_LAG_LOG_CHECKED_FLAG then
			_G.UBF_LAG_LOG_ENABLED = true
            _G.UBF_LAG_LOG_CHECKED_FLAG = true
            printx(21, "卡顿检查开启")
		end
	end, debug.traceback)
end

function UBFSLRuntime:init(createData)
    try_launch_lag_check()

    -- section create
    if createData.sectionData then 
        self:_buildCreateDataBySectionData(createData, createData.sectionData) 
    end

    -- parent init
    UBFProcessRuntime.init(self, createData)

    self.forceLuaGameLogic = createData.forceLuaGameLogic == true
    if self.forceLuaGameLogic then
        self.rustAvailable = nil
        self.so_rust = nil
    elseif _G.UBF_RUST_ALL_IN then
        self.rustAvailable = true
        self.so_rust = true
    else
        local _err
        if UBFPlaySwitch:isRustTestEnable() then 
            local ok, err = UBFPlaySwitch:isRustSupport(self.levelJsonData, self.levelId, self.levelScene, self.levelGroupInfo)
            if ok then 
                self.rustAvailable = true
                self.so_rust = {}
                -- math.randomseed(os.time())
                -- local randomPercent = UBFPlaySwitch:getRustRandomPercent()
                -- if math.random(100) <= randomPercent then
                --     self.so_rust = {}
                -- else
                --     _err = 99
                -- end
            else
                _err = err
            end
        end

        --
--
--
--

    end
    
    --mgr
    self.resMgr = UBFGameSceneResourceMgr:create()
    self.enterSourceHelper = require "ubf.UBFGamePlayScene.logics.processFlow.module.UBFSLEnterSourceHelper"

    --seed
    self.randomSeed = createData.randomSeed

    --replay
    self.replayLog = createData.replayLog
    self.wonderfulReplay = createData.wonderfulReplay
    if self.replayLog then
        if type(self.replayLog.gameUiVisualTuning) == "table" then
            local ok, helper = pcall(require, "ubf.debug.wc.dev.GameUiVisualTuningHelper")
            if ok and helper and helper.restoreReplayData then
                pcall(helper.restoreReplayData, self.replayLog)
            end
        end
        self.playId = self.replayLog[UBFFastUseEnum.gameEnvKey].playId
		self.randomSeed = self.replayLog[UBFFastUseEnum.gameEnvKey].randomSeed
        local ver = self.replayLog.ver or 1
        if ver == 2 then 
            self.so_rust = true
            if not UBFPlaySwitch:isRustTestEnable() then 
                if not UBFPlaySwitch:isRustEnableInThisPlatform() then 
                    UError("当前平台不支持Rust回放")
                end
                UBFPlaySwitch.isRustTestSwitchEnable = function() return true end
                if not UBFRustManager then require "ubf.UBFPlay.rust.UBFRustManager" end
			    UBFRustManager:tryInit()
            end
        else self.so_rust = nil end
    elseif _G._UBF_GAME_UI_VISUAL_REPLAY_ACTIVE then
        local ok, helper = pcall(require, "ubf.debug.wc.dev.GameUiVisualTuningHelper")
        if ok and helper and helper.clearReplayData then pcall(helper.clearReplayData) end
    end
    
    --section
    self.resumeData = createData.sectionData

    if self.resumeData then 
        local sectionData = self.resumeData
        local levelInfo = sectionData.levelInfo
        self.playId = sectionData.playId
        self.startTime = levelInfo.startTime
        self.startLevelType = levelInfo.startLevelType or UBFStartLevelType.kCommon
    else
        --playId
        self.playId = self.playId or createData.playId
        if not self.playId then 
            if self.editorMode or self._isInAIEnv then self.playId = "develop"
            else UBFThrow "找不到playId" end
        end

        --start time
        self.startTime = createData.startTime or Localhost:timeInSec()

        --other 
        self.startLevelType = createData.startLevelType or UBFStartLevelType.kCommon
    end

    -- TODO @gang.niu 从小游戏端迁过来的，只迁了这个字段，相关逻辑有待确认和迁移
    --连闯模式
    self.continuePlayMode = createData.continuePlayMode

    self.retryData = createData.retryData
    self.lastElRuntime = createData.lastElRuntime
    self.ai_actDataMap = createData.ai_actDataMap
    self.featureManager = nil --外部赋值

    self:_postInit()

    self:initLevelFarmingType(createData)

    self.enteringLevel = false

    self.UBFuuuAdjustLogic = UBFuuuSLRuntimeAdjustLogic.new()
end

function UBFSLRuntime:getLevelId()
    return self.levelId
end

function UBFSLRuntime:getLevelScene()
    return self.levelScene
end

function UBFSLRuntime:getLevelGroupInfo()
    return self.levelGroupInfo
end

function UBFSLRuntime:isInRust()
    return self.so_rust and true or false
end

function UBFSLRuntime:inContinuePlayMode()
    return self.continuePlayMode
end

function UBFSLRuntime:_buildCreateDataBySectionData(createData, sectionData)
    local levelInfo = sectionData.levelInfo
    createData.levelId = levelInfo.levelId
    createData.levelScene = levelInfo.levelScene
    createData.levelGroupInfo = levelInfo.levelGroupInfo
    -- dev 断面恢复：Editor 关卡不在关卡配置表里，用归档中保存的关卡配置兜底（见 UBFDebugSectionResume）
    if sectionData.devSectionResume == true and type(sectionData.devEditorLevelCfg) == "table" then
        createData.levelCfg = sectionData.devEditorLevelCfg
        createData.editorMode = true
    else
        createData.levelCfg = UBFLevelConfigManager:getLevelConfigByUUID(levelInfo.uuid)
    end
end

function UBFSLRuntime:_postInit()
    --migrator
    self.migrator = require 'ubf.UBFGamePlayScene.logics.processFlow.module.UBFSLMigrator'
    self:registerListenerByMap(self.migrator.gListener)

    --init other
    if self.resumeData then
        -- 闪退恢复
        self:_initOtherByResumeData(self.resumeData)
    elseif self.replayLog then
        -- 回放
        self:_initOtherByReplayData(self.replayLog)
    elseif self.editorMode then
        -- 编辑器 
        self:_initOtherOnEditor()
    elseif self:isAIMode() then
        -- AI
        self:_initOtherOnEditor()
    else
        -- 正常进关
        self:_initOtherByEnv()
    end
end

function UBFSLRuntime:_initOtherByReplayData(replayLog)
    local gEnv = replayLog.gEnv
    self.oldScore = gEnv.score
    self.oldStar = gEnv.oldStar
    self.uid = gEnv.uid
	self.udid = gEnv.uuid
	self.topLevelId = gEnv.topLevelId
    self.topPassedLevelId = gEnv.topPassedLevelId or 0
    self.curMd5 = gEnv.curMd5
end

function UBFSLRuntime:_initOtherByResumeData(resumeData)
    local levelInfo = resumeData.levelInfo
    self.so_rust = levelInfo.so_rust or nil
    self._resumeMode = true
    self.replayLog = resumeData.replayLog
	self.topLevelFailCount = levelInfo.topLevelFailCount
    self.oldScore = levelInfo.score or 0
    self.oldStar = levelInfo.star or 0
    self.scoreRefIsNil = levelInfo.scoreRefIsNil
    self.uid = levelInfo.uid
	self.udid = levelInfo.udid or "hasNoUdid"
	self.topLevelId = levelInfo.topLevelId
    self.topPassedLevelId = levelInfo.topPassedLevelId
    self.ubfGroupStr = levelInfo.ubfGroupStr
    self.curMd5 = levelInfo.curMd5
    self.jumpLevelCount = levelInfo.jumpLevelCount
    self.aiIHelpLevel = false
    self.passedLevel = levelInfo.passedLevel
    self.askerUid = levelInfo.askerUid
    self.userStars = levelInfo.userStars
    self.levelScene = levelInfo.levelScene or self.levelScene
    self.levelType = levelInfo.levelType or self.levelType
    self.outLevelAttachData = levelInfo.outLevelAttachData
    self.serverTopLevel = levelInfo.serverTopLevel or 0
    self.playLevelModeType = levelInfo.playLevelModeType
end

function UBFSLRuntime:_initOtherByEnv()
    -- todo 这种获取是外部设置还是使用UBFGameEnv?，直接获取不是个好方法！
    -- todo 另外考虑弄一些二级数据集合，都放到一级太多了可能会重
    self.topLevelFailCount = _G.amfBean("LevelAreaManager"):getTopLevelFailCount()
    self.topLevelWinCount = _G.amfBean("LevelAreaManager"):getTopLevelWinCount()
    self.isFullStarRecommendLevel = _G.amfBean("FarmLevelManager"):isLevelAvaliable(self.levelId, self.levelScene)
    self.fsllInfo = _G.amfBean("FullStarLevelLibManager"):getInLevelActData(self.levelId)
    self.serverTopLevel = _G.amfBean("LevelUnLockManager"):getUserMaxLevelId()
    self.playLevelModeType = UBFActHelper:getPlayLevelModeType2(self.levelId, self.levelScene)

    local scoreRef = UserManager:getInstance():getUserScore(self.levelId, self.levelScene)
    if scoreRef then 
    	self.oldScore = scoreRef.score or 0
	    self.oldStar = scoreRef.star or 0
        self.scoreRefIsNil = false
    else
        self.oldScore = 0
        self.oldStar = 0
        self.scoreRefIsNil = true
    end
    self.uid = UserManager:getInstance():getUID()
	self.udid = MetaInfo:getInstance():getUdid() or "hasNoUdid"
	self.topLevelId = UserManager:getInstance().user:getTopLevelId()
    self.topPassedLevelId = _G.amfBean("LevelAreaManager"):getTopPassedLevel()
    self.ubfGroupStr = UserManager:getInstance():getUBFGroupStr()
    self.curMd5 = ResourceLoader.getCurVersion()
    self.jumpLevelCount = _G.amfBean("JumpLevelManager"):getLevelPawnNum(self.levelId) or 0
    self.aiIHelpLevel = UserManager:getInstance():getIsAIHelpLevel(self.levelId)
    self.passedLevel = UserManager:getInstance():hasPassedLevel(self.levelId, self.levelScene)
    self.passedLevelEx = UserManager:getInstance():hasPassedLevelEx(self.levelId, self.levelScene)
    self.askerUid = _G.amfBean("AskForHelpManager"):getDoneeUId()
   
    local userMgr = _G.amfBean("UserManager")
    self.userStars = {
        totalTrunkStar = userMgr:getStar(),
        totalHideStar = userMgr:getHiddenStar(),
        colorfulStar = userMgr:getColorfulStar(),
    }
end

function UBFSLRuntime:_initOtherOnEditor()
    self.topLevelFailCount = 0
    self.topLevelWinCount = 0
    self.oldScore = 0
    self.oldStar = 0
    self.scoreRefIsNil = true
    self.uid = getSafeUid()
	self.udid = MetaInfo:getInstance():getUdid() or "hasNoUdid"
	self.topLevelId = 0
    self.topPassedLevelId = 0
    self.ubfGroupStr = ""
    self.curMd5 = ResourceLoader.getCurVersion()
    self.jumpLevelCount = 0
    self.aiIHelpLevel = false
    self.passedLevel = false
    self.passedLevelEx = false
    self.isFullStarRecommendLevel = false
    self.serverTopLevel = 0
    self.playLevelModeType = UBFActPlayLevelMode.TOP
end

function UBFSLRuntime:onLoadResourceFail()
    UBFProcessManager:showResourceLoadFailMessage()
end

function UBFSLRuntime:initLevelFarmingType(data)
    local levelId = self.levelId
    local levelType = self.levelType
    local topLevelId = self.topLevelId
    local oldStar = self.oldStar or 0

    if levelType == GameLevelType.kMainLevel then
        if oldStar >= 4 then
            self.levelFarmingType = UBFLevelFarmingType.FARM_SCORE
        elseif oldStar > 0 then
            self.levelFarmingType = UBFLevelFarmingType.FARM_STAR
        else
            if levelId == topLevelId then
                self.levelFarmingType = UBFLevelFarmingType.NORMAL
            else
                self.levelFarmingType = UBFLevelFarmingType.FARM_STAR
            end
        end
    elseif levelType == GameLevelType.kHiddenLevel then
        if oldStar >= 3 then
            self.levelFarmingType = UBFLevelFarmingType.FARM_SCORE
        elseif oldStar > 0 then
            self.levelFarmingType = UBFLevelFarmingType.FARM_STAR
        else
            self.levelFarmingType = UBFLevelFarmingType.NORMAL
        end
    else
        self.levelFarmingType = UBFLevelFarmingType.NORMAL
    end

end

--------------------****** *↓* ******--------------------
--					 外部逻辑 修改业务共享数据
--------------------****** *↑* ******--------------------


--[[
-- 更新连胜信息。
-- 如果你是一个连胜类的功能，调用此接口，声明你的连胜状态；后续mod可能基于你状态执行不同的逻辑分支
-- sourceName，来源名称，标识谁在调用此接口，打点用。活动的话默认传actId
-- winningStreakInfo 格式如下：
-- {
        modSourceId = 0,                                                    --[必需]
        winningStreakCount = 0,                                             --[必需]
        logicTypeMap = {                                                    --[必需]
            [UBFWinningStreakLogicType.kAddScore] = true,
            [UBFWinningStreakLogicType.kAddEffectOnBoard] = true,
        },              
        datas = nil,                                                        --[可选]
    }
--]]
function UBFSLRuntime:updateWinningStreakInfo(sourceName, winningStreakInfo)
    if not self.enabledWinningStreak then
        self.enabledWinningStreak = {}
    end

    if winningStreakInfo then
        winningStreakInfo.sourceName = sourceName
        table.insert( self.enabledWinningStreak, winningStreakInfo )
    end
end

-- 获取本次进关流程中的连胜信息。注意：返回调用时的连胜状态，调用时机不同，结果可能不同
function UBFSLRuntime:getWinningStreakInfo()
    return self.enabledWinningStreak
end

--------------------****** *↓* ******--------------------
--					 状态模式判断
--------------------****** *↑* ******--------------------

--专门指代精彩回放(回放)
function UBFSLRuntime:isReplayMode()
    return self.replayLog ~= nil
end

--是否为恢复模式
function UBFSLRuntime:isResumeMode() 
    return  self._resumeMode and self.resumeData
end

--是否为断面恢复
function UBFSLRuntime:isSectionResume() 
    return self:isResumeMode() and self.replayLog == nil
end

--是否为回放恢复
function UBFSLRuntime:isReplayResume() 
    return self:isResumeMode() and self.replayLog ~= nil
end

function UBFSLRuntime:isAskForHelp()
    return self:getStartLevelType() == UBFStartLevelType.kAskForHelp
end

function UBFSLRuntime:isJumpedLevel()
    return self.jumpLevelCount > 0
end

function UBFSLRuntime:isAIHelpedLevel()
    return self.aiIHelpLevel
end

function UBFSLRuntime:isPassedLevel()
    return self.passedLevel
end

-- 是否已过关（跳关代打也算）
function UBFSLRuntime:isPassedLevelEx()
    return self.passedLevelEx
end

-- 重玩状态，包含打关失败后的重玩，和未失败前玩家主动唤起的重玩
function UBFSLRuntime:isRetry()
    return self.retryData ~= nil
end

-- 玩家主动唤起的重玩（点击唤起重玩面板），此时打关还没有失败
function UBFSLRuntime:isRetryBeforeFail()
    if self.retryData then
        if self.retryData.failReason == UBFGameFailReason.kRetry then
            return true
        end
    end
    return false
end

-- 打关失败后的重玩
function UBFSLRuntime:isRetryAfterFail()
    if self.retryData then
        if self.retryData.failReason ~= UBFGameFailReason.kRetry then
            return true
        end
    end
    return false
end

function UBFSLRuntime:getLevelFarmingType()
    return self.levelFarmingType
end

function UBFSLRuntime:isEnteringLevel()
    return self.enteringLevel
end

function UBFSLRuntime:isFirstPlay()
    local isFirstPlay = UBFActHelper:ubfCheckIsFirstPlay(self.levelId, self.topLevelFailCount, self.levelScene)
    return isFirstPlay
end
--------------------****** *↓* ******--------------------
--					   信息获取
--------------------****** *↑* ******--------------------


function UBFSLRuntime:getPlayId() return self.playId end

function UBFSLRuntime:getProcessType() return UBFProcessTypeEnum.START_LEVEL end
function UBFSLRuntime:getStartLevelType() return self.startLevelType end
function UBFSLRuntime:getOldScore() return self.oldScore end
function UBFSLRuntime:getOldStar() return self.oldStar end
function UBFSLRuntime:getAdjustData() return self.adjustData end
function UBFSLRuntime:getDCData() return self.dcData end
function UBFSLRuntime:getEnableFuuuGraph() return self.adjustData ~= nil or self.useFuuuGraph or self:isAIMode() end
function UBFSLRuntime:getFuuuGraph()
    if self.fuuuGraphV3 then return  self.fuuuGraphV3 end
    return self.fuuuGraph
end
function UBFSLRuntime:getStartTime() return self.startTime end
function UBFSLRuntime:getUserTopLevel() return self.topLevelId end
function UBFSLRuntime:getUserTopPassedLevel() return self.topPassedLevelId end
function UBFSLRuntime:getScoreRefIsNil() return self.scoreRefIsNil end 
function UBFSLRuntime:getAskerUid() return self.askerUid end
function UBFSLRuntime:getFakeMetalLevelId()
    local group = UBFPlaySwitch:getLevelGroup(self.levelId, self.levelScene)
    if group == "default" then return 2000050 + self.levelId * 100 end
    return 2000051 + self.levelId * 100
end
function UBFSLRuntime:getResumeData() return self.resumeData end

function UBFSLRuntime:getEnterSourceHelper() 
    return self.enterSourceHelper 
end

-- NOTE 这两纯粹为了兼容旧代码，新的代码别用了
function UBFSLRuntime:getStartSource() return self.startSource end
function UBFSLRuntime:getDetailPanelParams() return self.detailPanelParams end

function UBFSLRuntime:getRetryData() return self.retryData end
function UBFSLRuntime:getLastElRuntime() return self.lastElRuntime end
function UBFSLRuntime:getStageState()
    if self.levelType == GameLevelType.kMainLevel then
        if self.passedLevel then return 2 end
        if self.scoreRefIsNil then return 0 end
        return 1
    end
    return nil
end

function UBFSLRuntime:getTopLevelWinCount()
    return self.topLevelWinCount    
end
function UBFSLRuntime:getTopLevelFailCount()
    return self.topLevelFailCount    
end

function UBFSLRuntime:getServerTopLevel()
    return self.serverTopLevel    
end
-- 此处是细分打关模式，见UBFActHelper:getPlayLevelModeType2(levelId, levelScene)
function UBFSLRuntime:getPlayLevelMode()
    return self.playLevelModeType    
end

--是否为刷分推荐关,关卡外在收到startLevel时就把刷分次数会+1了，导致后面LOAD_MOD会再次调用checkModIsEnabled，这时候通用的刷分判断就通不过了
function UBFSLRuntime:isFullStarLevelRecommended()
    return self.isFullStarRecommendLevel
end
--------------------****** *↓* ******--------------------
--					   设置获取
--------------------****** *↑* ******--------------------

function UBFSLRuntime:setFuuuGraph(fuuuGraph) self.fuuuGraph = fuuuGraph end
function UBFSLRuntime:setFuuuGraphV3(fuuuGraph) self.fuuuGraphV3 = fuuuGraph end
function UBFSLRuntime:setOutLevelAttachData(key, val) 
    if not self.outLevelAttachData then self.outLevelAttachData = {} end
    self.outLevelAttachData[key] = val
end
function UBFSLRuntime:setOldStar(oldStar) self.oldStar = oldStar end
function UBFSLRuntime:setProphet(key) self.rustProphetKey = key end
