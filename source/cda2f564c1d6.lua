-- 过关后炫耀（区域满星炫耀、全满星炫耀）
-- 强弹类型标记：
-- a = 单区域强弹 (OneAreaFullStarPanel)
-- b = 小节强弹 (TenAreaFullStarPanel) - 10个区域/150关
-- c = 星座强弹 (ConstellationFullStarPanel) - 100个区域/1500关
-- e = 星级跃迁 (StarLevelUpgradePanel)
--
-- 强弹优先级逻辑：
-- 1. 首先检查a是否有可领取的宝箱，若存在则强弹
-- 2. 随后按照e>c>b>a的逻辑，选择最大的且本流程之前未强弹过的面板强弹

local Module = class("PassLevelShowOffModule")
local Meta = require('amf.feature.fulllevel.areacompletion.config.Meta')
local MainSceneEventCenter = require 'amf.feature.mainscene.core.event.MainSceneEventCenter'

function Module:init(mgr)
    local mod = Module.new()
    self.mgr = mgr
    self.levelAreaManager = _G.amfBean("LevelAreaManager")
    self:registerEvent()
    return mod
end

function Module:registerEvent()
    if FeatureSwitch:isOpen(FeatureSwitch.Type.PASS_LEVEL_SHOW_OFF) then
        -- 使用统一的强弹处理入口，只注册一个优先级最高的事件
        MainSceneEventCenter:register(MainSceneEvent.Play.HANDLE_PASS_LEVEL, self.onHandleStellarConvergenceShowOff, self, MSP.PassLevel.LEVEL_SHOW_OFF)
    end
end

-- 统一的星光之域强弹处理入口
function Module:onHandleStellarConvergenceShowOff(evt)
    local data = evt:getData()
    local passedLevelId = data.passedLevelId
    local levelScene = data.levelScene
    local oldStar = data.oldStar
    local newStar = data.star
    local areaId = _G.amfBean("LevelAreaManager"):getAreaIdByLevelId(passedLevelId)

    local callback = function()
        evt:redeliver()
    end

    -- 新关期间，屏蔽强弹
    local ignore = _G.amfBean("AutoPopupMgr"):ignoreForTopLevelPlayer(passedLevelId, levelScene)
    if ignore then
        safeRunCall(callback)
        return
    end

    -- 非主线关卡不处理
    if not UBFLevelSceneFunc:isMainLevel(levelScene) then
        safeRunCall(callback)
        return
    end

    local StellarConvergenceManager = _G.amfBean("StellarConvergenceManager")

    -- 如果星光之域未启用或资源未准备好，走旧逻辑
    if not StellarConvergenceManager or not StellarConvergenceManager:isDataEnabled() or not StellarConvergenceManager:isNormalResReady() then
        self:runLegacyShowOffLogic(data, callback)
        return
    end

    -- 使用新的统一强弹逻辑
    self:runUnifiedShowOffLogic(data, callback)
end

-- 新的统一强弹逻辑
function Module:runUnifiedShowOffLogic(data, finalCallback)
    local passedLevelId = data.passedLevelId
    local levelScene = data.levelScene
    local oldStar = data.oldStar
    local newStar = data.star
    local areaId = _G.amfBean("LevelAreaManager"):getAreaIdByLevelId(passedLevelId)

    if areaId > 40000 then
        areaId = areaId - 40000
    end

    local StellarConvergenceManager = _G.amfBean("StellarConvergenceManager")

    -- 检查各类型面板的触发条件
    local checkResults = self:checkAllShowOffConditions(data, areaId, oldStar, newStar)

    local hasShowOff = (checkResults.a and checkResults.a.canShow)
        or (checkResults.b and checkResults.b.canShow)
        or (checkResults.c and checkResults.c.canShow)
        or (checkResults.e and checkResults.e.canShow)
    if hasShowOff then
        _G.amfBean("AutoPopupMgr"):blockPassLevelSkip()
    end

    -- 记录本次流程中已强弹的面板类型
    local shownPanels = {}

    -- 最终回调：在所有新面板逻辑之后，调用旧的全满星检查
    local afterAllPanelsCallback = function()
        self:tryOpenFullStarShowOffPanel(finalCallback)
    end

    -- 步骤1: 首先检查a（单区域）是否有可领取的宝箱 → 弹 a
    local step1Callback = function()
        -- 步骤2: 按 e>c>b>a 选最高的弹一个
        local priorityOrder = {"e", "c", "b", "a"}
        if not StellarConvergenceManager:isFullLevel() then
            priorityOrder = {"e", "b", "a"}
        end

        local selectedPanel = nil
        for _, panelType in ipairs(priorityOrder) do
            if not shownPanels[panelType] and checkResults[panelType] and checkResults[panelType].canShow then
                selectedPanel = {type = panelType, data = checkResults[panelType]}
                break
            end
        end

        if selectedPanel then
            self:showPanelByType(selectedPanel.type, selectedPanel.data, data, afterAllPanelsCallback)
        else
            afterAllPanelsCallback()
        end
    end

    if checkResults.a and checkResults.a.canShow and checkResults.a.hasReward then
        shownPanels["a"] = true
        self:showAreaFullStarPanel(checkResults.a, data, step1Callback)
    else
        step1Callback()
    end
end

-- 根据类型显示面板
function Module:showPanelByType(panelType, panelData, passLevelData, callback)
    if panelType == "a" then
        self:showAreaFullStarPanel(panelData, passLevelData, callback)
    elseif panelType == "b" then
        self:showSubsectionFullStarPanel(panelData, callback)
    elseif panelType == "c" then
        self:showConstellationFullStarPanel(panelData, callback)
    elseif panelType == "e" then
        self:showStarLevelChangePanel(panelData, callback)
    else
        safeRunCall(callback)
    end
end

-- 检查所有强弹条件
function Module:checkAllShowOffConditions(data, areaId, oldStar, newStar)
    local results = {}
    local StellarConvergenceManager = _G.amfBean("StellarConvergenceManager")

    -- a: 单区域满星检查
    results.a = self:checkAreaFullStar(areaId, oldStar, newStar)

    -- b: 小节满星检查（10个区域/150关）
    results.b = self:checkSubsectionFullStar(areaId, oldStar, newStar)

    -- c: 星座满星检查（100个区域/1500关）
    results.c = self:checkConstellationFullStar(areaId, oldStar, newStar)

    -- e: 星级跃迁检查
    results.e = self:checkStarLevelChange(data)

    return results
end

-- a: 检查单区域满星
function Module:checkAreaFullStar(areaId, oldStar, newStar)
    local result = {canShow = false, hasReward = false, isFullColor = false, areaId = areaId}

    local yellowNum, starNum = Meta:getYellowStarAndColorStarNum(areaId)

    -- 检查是否满星
    if (starNum == 45 and oldStar < 4) or (yellowNum == 45 and oldStar < 3) then
        result.canShow = true
        result.isFullColor = starNum == 45

        -- 检查是否有可领取的宝箱
        local StellarConvergenceManager = _G.amfBean("StellarConvergenceManager")
        if StellarConvergenceManager then
            local hasGotReward = StellarConvergenceManager:checkHasGotReward(areaId)
            local canOpenBoxToday = StellarConvergenceManager:getModel():checkCanOpenBoxToday()

            -- 有可领取的宝箱：未领过且今日次数未满
            result.hasReward = not hasGotReward and canOpenBoxToday
        end

        -- 如果仅满黄星（未满彩星）且没有奖励可领取，则不弹窗
        if not result.isFullColor and not result.hasReward then
            result.canShow = false
        end
        local ratingMgr = _G.amfBean("OhosRatingManager")
        if ratingMgr then
            ratingMgr:onAreaFullStar()
        end

    end

    return result
end

-- b: 检查小节满星（10个区域/150关）
function Module:checkSubsectionFullStar(areaId, oldStar, newStar)
    local result = {canShow = false, isFullColor = false, subsectionId = 0}
    local StellarConvergenceManager = _G.amfBean("StellarConvergenceManager")

    if not StellarConvergenceManager then return result end

    -- 旧星级更高或者新的小于3都不触发
    if (oldStar >= newStar) or (newStar < 3) then
        return result
    end

    local ONE_SUBSECTION_AREA_NUM = StellarConvergenceManager:getConst().ONE_SUBSECTION_AREA_NUM
    local AREA_LEVEL_NUM = StellarConvergenceManager:getConst().AREA_LEVEL_NUM

    local subsectionId = math.ceil(areaId / ONE_SUBSECTION_AREA_NUM)
    local areaStart = (subsectionId - 1) * ONE_SUBSECTION_AREA_NUM + 1
    local areaEnd = subsectionId * ONE_SUBSECTION_AREA_NUM

    local maxLevel = _G.amfBean("LevelUnLockManager"):getCanPlayTopLevel()
    local maxArea = maxLevel / AREA_LEVEL_NUM

    -- areaEnd大于目前最高区域，不触发
    if areaEnd > maxArea then
        return result
    end

    local allYellow = true
    local allColor = true

    for i = areaStart, areaEnd do
        local yellowStar, colorStar = _G.amfBean("LevelAreaManager"):getYellowStarAndColorStarNum(i)

        if yellowStar < AREA_LEVEL_NUM * 3 then
            allYellow = false
            allColor = false
            break
        end

        if colorStar < AREA_LEVEL_NUM * 3 then
            allColor = false
        end
    end

    if allColor and oldStar < 4 then
        result.canShow = true
        result.isFullColor = true
        result.subsectionId = subsectionId
    elseif allYellow and oldStar < 3 then
        result.canShow = true
        result.isFullColor = false
        result.subsectionId = subsectionId
    end

    return result
end

-- c: 检查星座满星（100个区域/1500关）
function Module:checkConstellationFullStar(areaId, oldStar, newStar)
    local result = {canShow = false, isFullColor = false, constellationIndex = 0}
    local StellarConvergenceManager = _G.amfBean("StellarConvergenceManager")

    if not StellarConvergenceManager then return result end

    -- 旧星级更高或者新的小于3都不触发
    if (oldStar >= newStar) or (newStar < 3) then
        return result
    end

    local AREA_LEVEL_NUM = StellarConvergenceManager:getConst().AREA_LEVEL_NUM
    local ONE_CONSTELLATION_AREA_NUM = math.floor(1500 / AREA_LEVEL_NUM)
    local constellationIndex = math.ceil(areaId / ONE_CONSTELLATION_AREA_NUM)
    local areaStart = (constellationIndex - 1) * ONE_CONSTELLATION_AREA_NUM + 1
    local areaEnd = constellationIndex * ONE_CONSTELLATION_AREA_NUM

    local maxLevel = _G.amfBean("LevelUnLockManager"):getCanPlayTopLevel()
    local maxArea = math.ceil(maxLevel / AREA_LEVEL_NUM)

    if areaEnd > maxArea then
        return result
    end

    local allYellow = true
    local allColor = true

    for i = areaStart, areaEnd do
        local yellowStar, colorStar = _G.amfBean("LevelAreaManager"):getYellowStarAndColorStarNum(i)

        if yellowStar < AREA_LEVEL_NUM * 3 then
            allYellow = false
            allColor = false
            break
        end

        if colorStar < AREA_LEVEL_NUM * 3 then
            allColor = false
        end
    end

    if allColor and oldStar < 4 then
        result.canShow = true
        result.isFullColor = true
        result.constellationIndex = constellationIndex
    elseif allYellow and oldStar < 3 then
        result.canShow = true
        result.isFullColor = false
        result.constellationIndex = constellationIndex
    end

    return result
end

-- e: 检查星级跃迁
function Module:checkStarLevelChange(data)
    local result = {canShow = false}
    local StellarConvergenceManager = _G.amfBean("StellarConvergenceManager")

    if not StellarConvergenceManager then
        return result
    end

    if not StellarConvergenceManager:isFullLevelResReady() then
        return result
    end

    local lastEndTime = StellarConvergenceManager:getLastEndTimeSec()
    local curTime = TimeKit:timeInSec()

    if not StellarConvergenceManager:isFullLevel() then
        return result
    end

    if lastEndTime <= 0 or curTime > lastEndTime then
        return result
    end

    -- 获取实际当前等级（过关后）
    local localCurLevel = StellarConvergenceManager:calCurRankType()
    -- 获取缓存的等级（进入游戏时已经校验过，是过关前的真实等级）
    local curRankType = StellarConvergenceManager:getCurRankType()

    -- 检查是否已经弹出过这个等级的跃迁面板
    local hasPopped = StellarConvergenceManager:getPopChangeType(localCurLevel)

    if curRankType < 1 then
        return result
    end

    -- 如果当前等级已经弹出过，不再弹
    if hasPopped then
        return result
    end

    -- curRankType < localCurLevel 说明升级了
    if curRankType < localCurLevel then
        result.canShow = true
        result.oldRankType = curRankType
        result.newRankType = localCurLevel
        return result
    end

    return result
end

-- 显示单区域满星面板
function Module:showAreaFullStarPanel(checkData, passLevelData, callback)
    local StellarConvergenceManager = _G.amfBean("StellarConvergenceManager")
    if StellarConvergenceManager and StellarConvergenceManager:isDataEnabled() and StellarConvergenceManager:isNormalResReady() then
        StellarConvergenceManager:showOneAreaFullStarPanel({
            isFullColor = checkData.isFullColor,
            areaId = checkData.areaId,
            closeCallback = callback,
            isPlayNextLevel = passLevelData.isContinuePlayMode,
        })
    else
        self:openAreaFullStarShowOffPanel(checkData.areaId, passLevelData.isContinuePlayMode, callback)
    end
end

-- 显示小节满星面板
function Module:showSubsectionFullStarPanel(checkData, callback)
    local StellarConvergenceManager = _G.amfBean("StellarConvergenceManager")
    if StellarConvergenceManager then
        StellarConvergenceManager:showTenAreaFullStarPanel({
            areaId = checkData.subsectionId,
            colorStar = checkData.isFullColor,
            closeCallback = callback
        })
    else
        safeRunCall(callback)
    end
end

-- 显示星座满星面板
function Module:showConstellationFullStarPanel(checkData, callback)
    local StellarConvergenceManager = _G.amfBean("StellarConvergenceManager")
    if StellarConvergenceManager then
        if checkData.isFullColor then
            StellarConvergenceManager:getDC():logConstellationFullColor(checkData.constellationIndex)
        else
            StellarConvergenceManager:getDC():logConstellationFullYellow(checkData.constellationIndex)
        end
        StellarConvergenceManager:showConstellationFullStarPanel({
            colorStar = checkData.isFullColor,
            closeCallback = callback,
            areaId = checkData.constellationIndex
        })
    else
        safeRunCall(callback)
    end
end

-- 显示星级跃迁面板
function Module:showStarLevelChangePanel(checkData, callback)
    local StellarConvergenceManager = _G.amfBean("StellarConvergenceManager")
    if StellarConvergenceManager then
        StellarConvergenceManager:showStarLevelChangePanel({
            oldRankType = checkData.oldRankType,
            newRankType = checkData.newRankType,
            callback = callback
        })
    else
        safeRunCall(callback)
    end
end

-- 旧的强弹逻辑（当星光之域不可用时）
function Module:runLegacyShowOffLogic(data, callback)
    local passedLevelId = data.passedLevelId
    local levelScene = data.levelScene
    local oldStar = data.oldStar
    local areaId = _G.amfBean("LevelAreaManager"):getAreaIdByLevelId(passedLevelId)

    if areaId > 40000 then
        areaId = areaId - 40000
    end

    local yellowNum, starNum = Meta:getYellowStarAndColorStarNum(areaId)
    if (starNum == 45 and oldStar < 4) or (yellowNum == 45 and oldStar < 3) then
        _G.amfBean("AutoPopupMgr"):blockPassLevelSkip()
        self:openAreaFullStarShowOffPanel(areaId, data.isContinuePlayMode, function()
            self:tryOpenFullStarShowOffPanel(callback)
        end)
    else
        self:tryOpenFullStarShowOffPanel(callback)
    end
end

-- 以下保留原有的旧版面板方法 --

-- 区域满星炫耀
function Module:openAreaFullStarShowOffPanel(areaId, jumpNextLevelId, callback)
    local AreaFullStarShowOffPanelVM = require "amf.feature.fulllevel.areacompletion.view.AreaFullStarShowOffPanelVM"
    local vm = AreaFullStarShowOffPanelVM.Builder.new()
        :setAreaId(areaId)
        :setJumpNextLevelId(jumpNextLevelId)
        :setCloseCallback(callback)
        :build()
    vm:popout()
end

-- 全满星炫耀
function Module:tryOpenFullStarShowOffPanel(callback)
    local totalStar = _G.amfBean("UserManager"):getTotalStar()
    local fullStarNum = _G.amfBean("LevelAreaManager"):getFullStarNum()
    if totalStar < fullStarNum then
        safeRunCall(callback)
        return
    end

    local cacheKey = "fullStarShowOffed_"..fullStarNum
    if self.mgr:getModel():getLocalCache(cacheKey) then
        safeRunCall(callback)
        return
    end

    local RequestOpNotifyOnline = require "amf.middleware.interconnection.remote.http.RequestOpNotifyOnline"
    local OpNotifyType = RequestOpNotifyOnline.OpType

    local function onSuccess(response)
        self.mgr:getModel():setLocalCache(cacheKey, true)
        local data = response:getData()
        if data then
            if _G.amfBean("HonorRankManager") and _G.amfBean("HonorRankManager"):checkAudit() and not data.audit then
                safeRunCall(callback)
                return
            end

            local fields = string.split(data.extra or '', ',') or {}
            local rank, ts, count = tonumber(fields[1]), tonumber(fields[2]), tonumber(fields[3])
            if rank and rank > 0 and ts then
                self:openFullStarShowOffPanel({
                    fullstar_rank = tonumber(fields[1]),
                    fullstar_ts = tonumber(fields[2]),
                    fullstar_count = tonumber(fields[3]),
                }, callback)
            else
                safeRunCall(callback)
            end
        else
            safeRunCall(callback)
        end
    end
    local function onFail(response)
        safeRunCall(callback)
    end

    RequestOpNotifyOnline:post(OpNotifyType.kFullStarCheck, nil, nil, true):next(onSuccess, onFail)
end

function Module:openFullStarShowOffPanel(data, callback)
    local FullStarShowOffPanelVM = require "amf.feature.fulllevel.areacompletion.view.FullStarShowOffPanelVM"
    local vm = FullStarShowOffPanelVM.Builder.new()
    :setData(data)
    :setCloseCallback(callback)
    :build()
    vm:popout()
end

return Module
