local Config = {}

Config.autoDownload = false
Config.downloadLabels = {'weektask'}

Config.logicVersion = 3


Config.actId = 3079
Config.ACT_ID = Config.actId 
Config.ACT_SOURCE = "weektask/Config.lua"
Config.GAME_NAME = "weektask"
Config.DCFeature = "WeekTask"
Config.DCSource = "act_"..Config.ACT_ID
Config.ACT_CH_NAME = "开心任务站" 
-- actInfo.extra 与主 info 共用的任务替换字段。
Config.REPLACE_TASKS_FIELD = "replaceTasks"

Config.TaskType = {
    INVALID = 'INVALID',
    LOGIN = 'TOTAL_LOGIN',
    PASS_LEVEL = 'PASS_LEVEL',
    COLLECT_RED = 'COLLECT_RED',
    COLLECT_MAGIC_BIRD = 'COLLECT_MAGIC_BIRD',
    MAGIC_RUSH_TOTAL_WIN = 'MAGIC_RUSH_TOTAL_WIN',
    MAGIC_RUSH_COLLECT_TIRE = 'MAGIC_RUSH_COLLECT_TIRE',
    MUSIC_ARTIS_COLLECT = 'MUSIC_ARTIS_COLLECT',
    FISH_WINNER_BOOK = 'FISH_WINER_BOOK',
    MERGE_COST_ENERGY = 'MERGE_COST_ENERGY',
    GROUP_ACT_COST_SHOVEL = 'GROUP_BUILDING_LEVEL_UP',
    LITTLE_MERGE_BOOK = 'LITTLE_MERGE_BOOK',
    LITTLE_MERGE_COST_ENERGY = 'LITTLE_MERGE_COST_ENERGY',
    CARD_COLLECT = 'CARD_COLLECT',
    CLEAR_MAP_COST_ENERGY = 'CLEAR_MAP_COST_ENERGY',
    BLOCK_ELIMINATE_COST_BLOCK = 'BLOCK_ELIMINATE_COST_BLOCK',
    RMB_ORDER = 'RMB',
}

Config.picPlistPath = "amf/activity/weektask/materials/weektaskicons.plist" 

Config.TaskMetas = {
    { taskType = Config.TaskType.INVALID, taskTip = "未知任务", clickTip = "未知任务", picPath = "icon1.png" },
    { taskType = Config.TaskType.LOGIN, taskTip = "累计登录%d天", clickTip = "登录游戏即可累计进度", picPath = "icon9.png" },
    { taskType = Config.TaskType.PASS_LEVEL, taskTip = "累计首闯%d关", taskTip2 = "累计补彩星%d关", taskTip3 = "累计随机挑战%d关", 
        clickTip = "首闯成功可累计进度", clickTip2 = "补彩星成功可累计进度", clickTip3 = "随机挑战成功可累计进度", 
        picPath = "icon2.png", picPath2 = "icon5.png", picPath3 = "icon1.png" 
    },

    { taskType = Config.TaskType.COLLECT_RED, taskTip = "累计消除%d个么么狐", clickTip = "在最高关消除么么狐", clickTip2 = "补星中消除么么狐", clickTip3 = "随机挑战中消除么么狐", picPath = "icon18.png" },
    { taskType = Config.TaskType.COLLECT_MAGIC_BIRD, taskTip = "累计消除%d个魔力鸟", clickTip = "在最高关消除魔力鸟", clickTip2 = "补星中消除魔力鸟", clickTip3 = "随机挑战中消除魔力鸟", picPath = "icon3.png" },
    { taskType = Config.TaskType.MAGIC_RUSH_TOTAL_WIN, taskTip = "累计获胜%d次", clickTip = "在魔力冲冲冲中获胜", picPath = "icon8.png" },
    { taskType = Config.TaskType.MAGIC_RUSH_COLLECT_TIRE, taskTip = "累计收集%d个轮胎", clickTip = "在魔力冲冲冲中获得轮胎", picPath = "icon8.png" },
    { taskType = Config.TaskType.MUSIC_ARTIS_COLLECT, taskTip = "累计收集%d个音符", clickTip = "在完美演奏家获得音符", picPath = "icon10.png" },
    { taskType = Config.TaskType.FISH_WINNER_BOOK, taskTip = "累计解锁%d个鱼类图鉴", clickTip = "钓鱼大赢家解锁新图鉴", picPath = "icon6.png" },
    { taskType = Config.TaskType.MERGE_COST_ENERGY, taskTip = "累计消耗%d个体力", clickTip = "在美味合合中消耗体力", picPath = "icon11.png" },
    { taskType = Config.TaskType.GROUP_ACT_COST_SHOVEL, taskTip = "累计组队完成%d次建筑升级", clickTip = "在露营吧朋友完成建筑升级", picPath = "icon12.png" },
    { taskType = Config.TaskType.LITTLE_MERGE_BOOK, taskTip = "累计解锁%d个木桩图鉴", clickTip = "在活动中解锁木桩图鉴", picPath = "icon14.png", picPath2 = "icon15.png"  },
    { taskType = Config.TaskType.LITTLE_MERGE_COST_ENERGY, taskTip = "累计消耗%d个体力", clickTip = "在活动中消耗体力", picPath = "icon14.png", picPath2 = "icon15.png" },
    { taskType = Config.TaskType.CARD_COLLECT, taskTip = "累计收集%d张卡片", clickTip = "在开心卡册中收集卡片", picPath = "icon7.png" },
    { taskType = Config.TaskType.CLEAR_MAP_COST_ENERGY, taskTip = "累计消耗%d能量", clickTip = "在活动中消耗能量", picPath = "icon16.png" },
    { taskType = Config.TaskType.BLOCK_ELIMINATE_COST_BLOCK, taskTip = "累计使用%d个方块", clickTip = "在方块消消中使用方块", picPath = "icon17.png" },
    { taskType = Config.TaskType.RMB_ORDER, taskTip = "惊喜任务：完成%d次付费", clickTip = "任意消费可得额外印章", picPath = "icon4.png" },
}

Config.GuideKey = {
    --播每日解锁动画
    kUnlockDay1 = 1,
    kUnlockDay2 = 2,
    kUnlockDay3 = 3,
    kUnlockDay4 = 4,
    kUnlockDay5 = 5,
    kUnlockDay6 = 6,
    kUnlockDay7 = 7,

    --播每日登录banner
    kLoginBannerDay1 = 11,
    kLoginBannerDay2 = 12,
    kLoginBannerDay3 = 13,
    kLoginBannerDay4 = 14,
    kLoginBannerDay5 = 15,
    kLoginBannerDay6 = 16,
    kLoginBannerDay7 = 17,

    kAllTaskComplete = 20,

}

Config.BoxMetas = {
    { boxId = 1, boxLevel = _G.UEBoxReward_Level.k1 },
    { boxId = 2, boxLevel = _G.UEBoxReward_Level.k1 },
    { boxId = 3, boxLevel = _G.UEBoxReward_Level.k2 },
    { boxId = 4, boxLevel = _G.UEBoxReward_Level.k3 },
    { boxId = 5, boxLevel = _G.UEBoxReward_Level.k4 },
    { boxId = 6, boxLevel = _G.UEBoxReward_Level.k5 },
}

Config.PlayLevelType = {
    kTopLevel= 1,
    kRefreshColorStar = 2,
    kFullLevelLib = 3,
}

function Config:getTaskMeta( taskType )
    for i,v in ipairs(Config.TaskMetas) do
        if v.taskType == taskType then
            return true, v
        end
    end
    return false, {}
end

function Config:getPlayLevelType(  )
    --获取闯关类型
    local playLevelType = Config.PlayLevelType.kTopLevel
    local UserStateManager = _G.amfBean("UserStateManager")
    if UserStateManager:isFMJ() then
        playLevelType = Config.PlayLevelType.kTopLevel
    elseif UserStateManager:isColorfulStarFull() then
        playLevelType = Config.PlayLevelType.kFullLevelLib
    else
        playLevelType = Config.PlayLevelType.kRefreshColorStar
    end
    return playLevelType
end

function Config:getTaskTipStr( taskType, target, taskFlag )

    if taskFlag == nil or taskFlag == 0 then 
        taskFlag = self:getPlayLevelType() 
    end

    local showStr = ""
    local bSucess, taskMeta = self:getTaskMeta(taskType)
    if bSucess then
        local tipStr = taskMeta.taskTip
        if taskType == Config.TaskType.PASS_LEVEL then
            local playLevelType = taskFlag
            
            if playLevelType == Config.PlayLevelType.kTopLevel then
                tipStr = taskMeta.taskTip
            elseif playLevelType == Config.PlayLevelType.kFullLevelLib then
                tipStr = taskMeta.taskTip3
            elseif playLevelType == Config.PlayLevelType.kRefreshColorStar then
                tipStr = taskMeta.taskTip2
            end
        end
        showStr = string.format( tipStr, target )
    end
    return showStr
end

function Config:getTaskClickTipStr( taskType, target, taskFlag )

    if taskFlag == nil or taskFlag == 0 then 
        taskFlag = self:getPlayLevelType() 
    end

    local showStr = ""
    local bSucess, taskMeta = self:getTaskMeta(taskType)
    if bSucess then
        local tipStr = taskMeta.clickTip
        if taskType == Config.TaskType.PASS_LEVEL or taskType == Config.TaskType.COLLECT_RED or taskType == Config.TaskType.COLLECT_MAGIC_BIRD then
            local playLevelType = taskFlag
            
            if playLevelType == Config.PlayLevelType.kTopLevel then
                tipStr = taskMeta.clickTip
            elseif playLevelType == Config.PlayLevelType.kFullLevelLib then
                tipStr = taskMeta.clickTip3
            elseif playLevelType == Config.PlayLevelType.kRefreshColorStar then
                tipStr = taskMeta.clickTip2
            end
        end
        showStr = string.format( tipStr, target )
    end
    return showStr
end

function Config:getTaskResPath( taskType, target, taskFlag )

    if taskFlag == nil or taskFlag == 0 then 
        taskFlag = self:getPlayLevelType() 
    end
    
    local resPath = ""
    local bSucess, taskMeta = self:getTaskMeta(taskType)
    if bSucess then
        if taskType == Config.TaskType.PASS_LEVEL then
            local playLevelType = taskFlag
            if playLevelType == Config.PlayLevelType.kTopLevel then
                resPath = "weektaskicons/"..taskMeta.picPath
            elseif playLevelType == Config.PlayLevelType.kFullLevelLib then
                resPath = "weektaskicons/"..taskMeta.picPath3
            elseif playLevelType == Config.PlayLevelType.kRefreshColorStar then
                resPath = "weektaskicons/"..taskMeta.picPath2
            else
                resPath = "weektaskicons/"..taskMeta.picPath
            end
        elseif taskType == Config.TaskType.LITTLE_MERGE_BOOK or taskType == Config.TaskType.LITTLE_MERGE_COST_ENERGY then
            --小merge
            if _G.amfBean("MergeEvolutionManager") and _G.amfBean("MergeEvolutionManager"):isEnabled() then
                resPath = "weektaskicons/"..taskMeta.picPath2
            elseif _G.amfBean("MusicMergeManager") and _G.amfBean("MusicMergeManager"):isEnabled() then
                resPath = "weektaskicons/"..taskMeta.picPath
            else
                resPath = "weektaskicons/"..taskMeta.picPath2
            end
        else
            resPath = "weektaskicons/"..taskMeta.picPath
        end
    end
    return resPath
end

function Config:getBoxMeta( boxId )
    for i,v in ipairs(Config.BoxMetas) do
        if v.boxId == boxId then
            return true, v
        end
    end
    return false, {}
end

function Config:getTaskTypeByActTaskType( actTaskType )

    if actTaskType == _G.WeekTaskType.MAGIC_RUSH_WIN_NUM then
        return Config.TaskType.MAGIC_RUSH_TOTAL_WIN
    elseif actTaskType == _G.WeekTaskType.MAGIC_RUSH_COLLECT_TIRE then
        return Config.TaskType.MAGIC_RUSH_COLLECT_TIRE
    elseif actTaskType == _G.WeekTaskType.MUSIC_MASTER_GET_COLLECT then
        return Config.TaskType.MUSIC_ARTIS_COLLECT
    elseif actTaskType == _G.WeekTaskType.FISH_GET_HANDBOOK then
        return Config.TaskType.FISH_WINNER_BOOK
    elseif actTaskType == _G.WeekTaskType.MERGE_USE_ENERGY then
        return Config.TaskType.MERGE_COST_ENERGY
    elseif actTaskType == _G.WeekTaskType.GROUP_ACT_BUILD_LEVELUP then
        return Config.TaskType.GROUP_ACT_COST_SHOVEL
    elseif actTaskType == _G.WeekTaskType.LITTLE_MERGE_UNLOCK_HANDBOOK then
        return Config.TaskType.LITTLE_MERGE_BOOK
    elseif actTaskType == _G.WeekTaskType.LITTLE_MERGE_USE_ENERGY then
        return Config.TaskType.LITTLE_MERGE_COST_ENERGY
    elseif actTaskType == _G.WeekTaskType.CARD_ACT_GET_NUM then
        return Config.TaskType.CARD_COLLECT
    elseif actTaskType == _G.WeekTaskType.CLEAR_MAP_COST_ENERGY then
        return Config.TaskType.CLEAR_MAP_COST_ENERGY
    elseif actTaskType == _G.WeekTaskType.BLOCK_ELIMINATE_COST_BLOCK then
        return Config.TaskType.BLOCK_ELIMINATE_COST_BLOCK
    end

    return Config.TaskType.INVALID
end

return Config
