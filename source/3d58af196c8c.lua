local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require 'amf.middleware.activity.event.ActivityEventCenter'
local HapticsHelper = require 'amf.feature.localactivity.weektask.haptics.HapticsHelper'
local WeekTaskMusic = require 'amf.feature.localactivity.weektask.module.WeekTaskMusic'
local WeekTaskEventCenter = require 'amf.feature.localactivity.weektask.event.WeekTaskEventCenter'

local WeekTaskManager = class("WeekTaskManager",BaseFeatureManager)

local function ignoreForTopLevelPlayer()
    local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
    if userState == _G.UserStateConst.UserLevelState.MHZC then
        return false
    end
    local levelUnlockManager = _G.amfBean("LevelUnLockManager")
    if not levelUnlockManager:isTopNewMainLevel(_G.getTopLevelId()) then
        return false
    end
    if not levelUnlockManager:isInNewLevelTime() then
        return false
    end
    return true
end


local LOCAL_PATH = 'amf.feature.localactivity.weektask'

local WeekTaskBanner = require (LOCAL_PATH..'.module.WeekTaskBanner')

function WeekTaskManager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
end

function WeekTaskManager:_init()
    -- 缓存最近一次服务端 actInfo 下发的被 Ban 活动 ID，只影响后续任务进度。
    self.bannedActIdMap = {}
    self.weekTaskBanner = WeekTaskBanner:create()
    self.hapticsHelper = HapticsHelper:create()
    self.weekTaskMusic = WeekTaskMusic:create()

    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)

    ActivityEventCenter:registerGlobal(NormalEvent.PAYMENT_SUCCESS, self.onOrderSuccess, self)

    WeekTaskEventCenter:register(_G.WeekTaskEvent.ACT_TASK_COMPLETE, self.onReceiveActTask, self)

    self:initPlugs()
end

function WeekTaskManager:initPlugs()
    self:_initPlug("ActSend",{
        plugPath = "amf.feature.localactivity.weektask.plug.WeekTaskActSendPlug"
    })
end

function WeekTaskManager:_getExtraPlugsConfigList()
    return {
        {key = "AutoPop"},
        {key = "Panel"},
        {key = "Download"},
    }
end

function WeekTaskManager:_getAutoPopConfigList()
    if not (EnvUtil:isDevelopMode() or EnvUtil:isMiniGame()) then
        return {}
    end
    return {
        {
            checkPoint = PopupCheckPoint.WEEK_TASK_STAGE4_MAIN,
            actId = self:getConst().ACT_ID,
            stages = {AutoPopupConst.PopStage.STAGE_FOUR},
            check = function()
                if not self:isActivitySupported(self:getConst().ACT_ID) then return false end
                return self:isEnabled()
            end,
            pop = function(_, onPopOver)
                return function()
                    self:openActivity(onPopOver, nil, false)
                end
            end,
        },
        {
            checkPoint = PopupCheckPoint.WEEK_TASK_STAGE3_POP,
            actId = self:getConst().ACT_ID,
            stages = {
                AutoPopupConst.PopStage.STAGE_THREE,
                AutoPopupConst.PopStage.STAGE_FOUR,
            },
            check = function()
                if not self:isActivitySupported(self:getConst().ACT_ID) then return false end
                return not ignoreForTopLevelPlayer() and self:checkCanPopStage3() == true
            end,
            pop = function(_, onPopOver)
                return function()
                    self:doPopStage3(onPopOver)
                end
            end,
        },
    }
end

-- 获取model路径
function WeekTaskManager:_getModelPath()
    return LOCAL_PATH..'.model.WeekTaskModel'
end

function WeekTaskManager:_getConstPath()
    return LOCAL_PATH..'.config.WeekTaskConfig'
end

function WeekTaskManager:getActInfo()
    local actInfo

    local activityMgr =_G.amfBean("ActivityMgr")
    if activityMgr then
    	actInfo = activityMgr:getActInfo(self:getConst().ACT_ID)
    end
    return actInfo
end

function WeekTaskManager:onActActInfoUpdate(event)

    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().ACT_ID)]

    if not actInfo and fromServer then
        -- 完整服务端刷新中周任务已下线，同时清理旧的 Ban 缓存。
        self:updateBannedActIds()
        self:getModel():reset()
        ActivityEventCenter:dispatch(ActivityEvent.REMOVE_ACTIVITY,{actId = self:getConst().ACT_ID})
        return
    end

    if actInfo and fromServer then
        -- 只使用服务端完整 actInfo 更新 Ban 状态，避免本地单活动更新覆盖缓存。
        self:updateBannedActIds(actInfo)
    end
end

function WeekTaskManager:updateBannedActIds(actInfo)
    -- 正式协议格式：actInfo.extra JSON 中的 replaceTasks[i].relateActId 表示被 Ban 的活动 ID。
    local extraData = {}
    if actInfo and actInfo.extra then
        extraData = table.deserialize(actInfo.extra) or {}
    end
    local replaceTasks = extraData[self:getConst().REPLACE_TASKS_FIELD] or {}
    self.bannedActIdMap = {}
    for _, replaceTask in ipairs(replaceTasks) do
        local actId = replaceTask and replaceTask.relateActId
        -- 兼容数字和数字字符串，统一使用字符串作为查询键。
        if tonumber(actId) and tonumber(actId) > 0 then
            self.bannedActIdMap[tostring(actId)] = true
        end
    end
end

function WeekTaskManager:getTaskRelatedActId(taskType)
    local TaskType = self:getConst().TaskType

    -- 与动态周任务 TaskCell:goBtnCall() 保持一致，各活动按自身接口单独取 ID。
    if taskType == TaskType.MAGIC_RUSH_TOTAL_WIN or taskType == TaskType.MAGIC_RUSH_COLLECT_TIRE then
        -- 魔力冲冲冲：Const.actId。
        local magicRushManager = _G.amfBean("MagicRushManager")
        return magicRushManager and magicRushManager:getConst().actId
    elseif taskType == TaskType.MUSIC_ARTIS_COLLECT then
        -- 完美演奏家：WinningStreak 子模块 Manager 的 Const.ACT_ID。
        local winningStreakManager = _G.amfBean("WinningStreakManager")
        local moduleType = _G.WSConst and _G.WSConst.ModuleType and _G.WSConst.ModuleType.MUSICMASTER
        local module = winningStreakManager and moduleType and winningStreakManager:getModule(moduleType)
        local musicMasterManager = module and module.mgr
        return musicMasterManager and musicMasterManager:getConst().ACT_ID
    elseif taskType == TaskType.FISH_WINNER_BOOK then
        -- 钓鱼大赢家：Manager.ACT_ID。
        local fishingWinnerManager = _G.amfBean("FishingWinnerManager")
        return fishingWinnerManager and fishingWinnerManager.ACT_ID
    elseif taskType == TaskType.MERGE_COST_ENERGY then
        -- 美味合合：Manager.ACT_ID。
        local mergeManager = _G.amfBean("MergeManager")
        return mergeManager and mergeManager.ACT_ID
    elseif taskType == TaskType.GROUP_ACT_COST_SHOVEL then
        -- 组队活动：Const.actId。
        local teamCampingManager = _G.amfBean("TeamCampingManager")
        return teamCampingManager and teamCampingManager:getConst().actId
    elseif taskType == TaskType.LITTLE_MERGE_BOOK or taskType == TaskType.LITTLE_MERGE_COST_ENERGY then
        -- 小 Merge 共用任务类型，按 TaskCell 的顺序选择当前启用的活动。
        local mergeEvolutionManager = _G.amfBean("MergeEvolutionManager")
        local musicMergeManager = _G.amfBean("MusicMergeManager")
        if mergeEvolutionManager and mergeEvolutionManager:isEnabled() then
            return mergeEvolutionManager:getConst().actId
        elseif musicMergeManager and musicMergeManager:isEnabled() then
            return musicMergeManager:getConst().actId
        end
        return (mergeEvolutionManager and mergeEvolutionManager:getConst().actId)
            or (musicMergeManager and musicMergeManager:getConst().actId)
    elseif taskType == TaskType.CLEAR_MAP_COST_ENERGY then
        -- 迷雾清图：Const.actId。
        local exploreMapGameManager = _G.amfBean("ExploreMapGameManager")
        return exploreMapGameManager and exploreMapGameManager:getConst().actId
    elseif taskType == TaskType.BLOCK_ELIMINATE_COST_BLOCK then
        -- 方块消消：Const.actId。
        local blockManager = _G.amfBean("BlockManager")
        return blockManager and blockManager:getConst().actId
    elseif taskType == TaskType.CARD_COLLECT then
        -- 开心卡册：Manager.ACT_ID。
        local collectCardManager = _G.amfBean("CollectCardManager")
        return collectCardManager and collectCardManager.ACT_ID
    end
end

function WeekTaskManager:getTaskRelatedActName(taskType, relatedActId)
    local TaskType = self:getConst().TaskType

    -- 与 getTaskRelatedActId() 保持相同分支，只访问当前任务对应的活动 Manager。
    if taskType == TaskType.MAGIC_RUSH_TOTAL_WIN or taskType == TaskType.MAGIC_RUSH_COLLECT_TIRE then
        local magicRushManager = _G.amfBean("MagicRushManager")
        return magicRushManager and magicRushManager:getConst().ACT_CH_NAME
    elseif taskType == TaskType.MUSIC_ARTIS_COLLECT then
        local winningStreakManager = _G.amfBean("WinningStreakManager")
        local moduleType = _G.WSConst and _G.WSConst.ModuleType and _G.WSConst.ModuleType.MUSICMASTER
        local module = winningStreakManager and moduleType and winningStreakManager:getModule(moduleType)
        local musicMasterManager = module and module.mgr
        return musicMasterManager and musicMasterManager:getConst().ACT_CH_NAME
    elseif taskType == TaskType.FISH_WINNER_BOOK then
        local fishingWinnerManager = _G.amfBean("FishingWinnerManager")
        return fishingWinnerManager and fishingWinnerManager.ACT_CH_NAME
    elseif taskType == TaskType.MERGE_COST_ENERGY then
        local mergeManager = _G.amfBean("MergeManager")
        return mergeManager and mergeManager.ACT_CH_NAME
    elseif taskType == TaskType.GROUP_ACT_COST_SHOVEL then
        local teamCampingManager = _G.amfBean("TeamCampingManager")
        return teamCampingManager and teamCampingManager:getConst().actChName
    elseif taskType == TaskType.LITTLE_MERGE_BOOK or taskType == TaskType.LITTLE_MERGE_COST_ENERGY then
        local mergeEvolutionManager = _G.amfBean("MergeEvolutionManager")
        if mergeEvolutionManager and tostring(relatedActId) == tostring(mergeEvolutionManager:getConst().actId) then
            return mergeEvolutionManager:getActName()
        end

        local musicMergeManager = _G.amfBean("MusicMergeManager")
        if musicMergeManager and tostring(relatedActId) == tostring(musicMergeManager:getConst().actId) then
            return musicMergeManager:getActName()
        end
    elseif taskType == TaskType.CLEAR_MAP_COST_ENERGY then
        local exploreMapGameManager = _G.amfBean("ExploreMapGameManager")
        return exploreMapGameManager and exploreMapGameManager:getConst().actChName
    elseif taskType == TaskType.BLOCK_ELIMINATE_COST_BLOCK then
        local blockManager = _G.amfBean("BlockManager")
        return blockManager and blockManager:getConst().actChName
    elseif taskType == TaskType.CARD_COLLECT then
        local collectCardManager = _G.amfBean("CollectCardManager")
        return collectCardManager and collectCardManager.ACT_CH_NAME
    end
end

function WeekTaskManager:isTaskRelatedActBanned(taskType)
    local actId = self:getTaskRelatedActId(taskType)
    return actId and self.bannedActIdMap[tostring(actId)] == true
end

function WeekTaskManager:fromServer(data, config )
    self:getModel():fromServer(data,config)

    self.downloadPlug:startDownload()
end

function WeekTaskManager:hasReward()
    if not self:isEnabled() then return end

    return self:getModel():hasProgressBoxCanGet()
end

function WeekTaskManager:getMsgNum()
    if not self:isEnabled() then return end

    if self:getModel():isInRewardTime() then
        return 0
    else
        return self:getModel():getTotalCanCompleteTaskCount()
    end
end

function WeekTaskManager:createCollectIcon(  )
    local item = UICreateUtil:createSpriteWithPlist(self:getConst().picPlistPath, "weektaskicons/collectIcon.png")
    return item
end

function WeekTaskManager:createActIcon( )
    local item = UICreateUtil:createSpriteFile( "amf/activity/weektask/materials/actIcon.png")
    return item
end

function WeekTaskManager:isEnabled(  )
    if (self:getModel():isInMainTime() ) then
        self.downloadPlug:startDownload()
        return true
    else
        return false
    end
end

function WeekTaskManager:isEnabled2(  )
    if (self:getModel():isInMainTime() or self:getModel():isInRewardTime() ) then
        self.downloadPlug:startDownload()
        return true
    else
        return false
    end
end

function WeekTaskManager:getMainEndTime()
    return self:getModel():getMainEndTime()
end

function WeekTaskManager:isEnabledAndResComplete()
    return self:isEnabled() and self:checkResDownLoadSucess()
end

function WeekTaskManager:isEnabled2AndResComplete()
    return self:isEnabled2() and self:checkResDownLoadSucess()
end

function WeekTaskManager:checkResDownLoadSucess(  )
    return self.downloadPlug:checkDownloadSuccess()
end

function WeekTaskManager:taskAddNum( inTaskType, addNum )
    if not self:isEnabled() then return end
    -- 保留活动被 Ban 前的已有进度，仅停止维护后续新增进度。
    if self:isTaskRelatedActBanned(inTaskType) then return end
    local completeTaskInfos = self:getModel():taskAddNum( inTaskType, addNum )
    self:callPlug("Act", "updateTipView")
    return completeTaskInfos
end
---------------
---检测任务完成
---------------
function WeekTaskManager:getLoginPopKey(weekDay)
    local key = self:getConst().GuideKey['kLoginBannerDay'..weekDay]
    return key
end

function WeekTaskManager:loginTask()
    --登录任务完成推送
    if not self:isEnabled() then return end
    local completeTaskInfos = {}
    local bGetSucess, info = self:getModel():getTodayLoginBroadInfo()
    -- printx(12,":bGetSucess",bGetSucess, tts(info))
    if bGetSucess then
        local key = self:getLoginPopKey( info.weekDay )
        if not self:getModel():checkGuide(key) then
            table.insert( completeTaskInfos, info )
            self:addActCompleteInfos(completeTaskInfos)
            self.weekTaskBanner:doPopBanner()
            self:getModel():setGuideIndex(key)
        end
    end
end

function WeekTaskManager:onActPassDay()
    --跨天检测登录强弹
    if not self:isEnabled() then return end
    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then return end
    self:taskAddNum( self:getConst().TaskType.LOGIN, 1 )
    self:loginTask()
end


local function _isMainScene()
    local scene = Director:sharedDirector():getRunningSceneLua()
    if scene == nil or not scene:isScene("MainScene") then
        return false
    end
    return true
end

-- 购买成功tip
function WeekTaskManager:onOrderSuccess(event)
    if not self:isEnabled() then return end
    local data = event:getData()
    if not data or not data.goodsId then return end

    local goodsId = data.goodsId
    local payType = data.payType
    local isRmb = data.isRmb
    if isRmb then
        local completeTaskInfos = self:taskAddNum( self:getConst().TaskType.RMB_ORDER, 1 )

        local popBanner = false
        if _isMainScene() then
            popBanner = true
        end
        self:addActCompleteInfos(completeTaskInfos, popBanner)
    end
end

function WeekTaskManager:onActBeforePlayLevelEnd(data)
    -- --过关记录、关卡内障碍收集，等待场景3强弹
    -- if not self:isEnabled() then return end

    -- local data = data:getData()
    -- --消除鸟的数量
    -- local birdDestroyCount = data.birdDestroyCount or 0

    -- local completeTaskInfos = self:taskAddNum( self:getConst().TaskType.COLLECT_MAGIC_BIRD, birdDestroyCount )
    -- self:addActCompleteInfos(completeTaskInfos, false)
end

function WeekTaskManager:onReceiveActTask(evt)
    --各个活动的任务完成事件
    if not self:isEnabled() then return end

    local data = evt:getData()

    if data.type then
        local taskType = self:getConst():getTaskTypeByActTaskType(data.type)
        local completeTaskInfos = self:taskAddNum( taskType, data.num )
        self:addActCompleteInfos(completeTaskInfos)
    end
end

function WeekTaskManager:addActCompleteInfos(completeTaskInfos, popBanner )
    --进行推送
    if popBanner == nil then popBanner = true end
    self.weekTaskBanner:addActCompleteInfos(completeTaskInfos)
    if popBanner then
        self.weekTaskBanner:doPopBanner()
    end
end

function WeekTaskManager:checkCanPopStage3()
    --强弹检测
    if not self:isEnabled() then return end
    return self.weekTaskBanner:checkCanPopStage3()
end

function WeekTaskManager:doPopStage3( endCall )
    --强弹
    if self:checkCanPopStage3() then
        self.weekTaskBanner:doPopBanner()
    end
    safeRunCall(endCall)
end

function WeekTaskManager:dc(category, subCategory, extraData)
    local params = {
        game_type = "stage",
        category = category,
        sub_category = subCategory,
    }

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end
    -- printx(12,"WeekTaskManager dc",tts(params))
    DcUtil:dcForUserTrack(params)
end

function WeekTaskManager:openActivity(closeCallback, extra, userClick, duanMianData)
    ActivityEventCenter:dispatch(ActivityEvent.OPEN_ACTIVITY, {
        actId = self:getConst().ACT_ID,
        failCallback = closeCallback,
        endCallback = closeCallback,
        userClick = userClick,
        extra = extra,
        duanMianData = duanMianData
    })
end

---------------------------------- 
--测试
---------------------------------- 
function WeekTaskManager:testBroadCast()
    if not EnvUtil:isDevelopMode() then return end
    local WeekTaskBroadCastContext = require 'amf.feature.localactivity.weektask.broadcast.WeekTaskBroadCastContext'
    local context = WeekTaskBroadCastContext:create(9999)
    context:setPopInfo( { weekDay = 1, taskId=3, taskType = "PASS_LEVEL", oldValue = 2, newValue = 3}) 
    _G.amfTransaction(TransactionEvent.BROADCAST, context)
end

function WeekTaskManager:testBroadCast2()
    if not EnvUtil:isDevelopMode() then return end
    local WeekTaskBroadCastContext = require 'amf.feature.localactivity.weektask.broadcast.WeekTaskBroadCastContext'
    local context = WeekTaskBroadCastContext:create(9999)
    context:setPopInfo({moreComplete=true}) 
    _G.amfTransaction(TransactionEvent.BROADCAST, context)
end

---------------------------------- 关卡内 begin--------------------------------
--关卡内触发条件
function WeekTaskManager:isEnabledInLevel(data)
    if not self:isEnabled() then return false end
    return true
end

--关卡内活动启动数据
function WeekTaskManager:getInLevelActData(levelId)
    local inLevelActData = {
        -- 业务逻辑版本号
        logicVersion = self:getConst().logicVersion
    }
    return inLevelActData
end

--打关结束时更新数据
function WeekTaskManager:updatePassLevelData(data, mainCollectionCount, collectionMap, passLevelData)
    local passLevelJson = passLevelData and passLevelData.passLevelJson
    if passLevelJson then
        -- 已完成闯关任务：非满级打top 、满级未满星补彩星、 满级满星打关卡库，三个任务可以加1， 等待场景3弹出
        if passLevelJson.needUpdateTask then
            local completeTaskInfos = self:taskAddNum( self:getConst().TaskType.PASS_LEVEL, 1 )
            self:addActCompleteInfos(completeTaskInfos, false)
        end
        
        -- 魔力鸟任务
        local birdDestroyCount = passLevelJson and passLevelJson.magicBird or 0
        if birdDestroyCount > 0 then
            local completeTaskInfos = self:taskAddNum( self:getConst().TaskType.COLLECT_MAGIC_BIRD, birdDestroyCount )
            self:addActCompleteInfos(completeTaskInfos, false)
        end
        -- 收集红色颜色动物任务
        local redAnimalDestroyCount = passLevelJson and passLevelJson.red or 0
        if redAnimalDestroyCount > 0 then
            local completeTaskInfos = self:taskAddNum( self:getConst().TaskType.COLLECT_RED, redAnimalDestroyCount )
            self:addActCompleteInfos(completeTaskInfos, false)
        end
    end
end



return WeekTaskManager
