local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"

local ACT_NAME = "colorfulstar"
local LOCAL_PATH = 'amf.feature.winningstreak.module.' .. string.lower(ACT_NAME)

local ColorfulStarWinRepeatManager = class("ColorfulStarWinRepeatManager", BaseFeatureManager)

local init_inLevelFunc = require(LOCAL_PATH .. '.ColorfulStarWinRepeatManager_InLevel')
init_inLevelFunc(ColorfulStarWinRepeatManager)


local init_StartPanelFunc = require(LOCAL_PATH .. '.ColorfulStarWinRepeatManager_StartPanel')
init_StartPanelFunc(ColorfulStarWinRepeatManager)
local ColorfulStarWinRepeatDC = require "amf.feature.winningstreak.module.colorfulstar.dc.ColorfulStarWinRepeatDC"

local _instance = nil
function ColorfulStarWinRepeatManager:getInstance()
    if not _instance then
        _instance = ColorfulStarWinRepeatManager.new()
        _instance:initialize()
    end
    return _instance
end

function ColorfulStarWinRepeatManager:_init()
    self.dcUtil = ColorfulStarWinRepeatDC:new()
    self.passLevelCanShowUI = false
    self.meta = self:getConst()
    self.actId = self.meta.ACT_ID
    self.showName = '彩星连胜'
end

function ColorfulStarWinRepeatManager:getConst()
    return require(self:_getConstPath())
end

function ColorfulStarWinRepeatManager:_getExtraPlugsConfigList()
    return {
        { key = "Panel" },
        { key = "Download" },
    }
end

-- 获取model路径
function ColorfulStarWinRepeatManager:_getModelPath()
    return LOCAL_PATH .. '.model.model'
end

function ColorfulStarWinRepeatManager:_getConstPath()
    return LOCAL_PATH .. '.const.const'
end

function ColorfulStarWinRepeatManager:getData()
    return self:getModel()
end

function ColorfulStarWinRepeatManager:passDayRefreshData()
    self:onPassDay()

    if self:getData():isInMainTime() then
        self:getData():passDayClear()
    end
end

function ColorfulStarWinRepeatManager:onPassDay()
    local observerNum = self:getObserverNum()
    if observerNum > 0 then
        self:notify(self:getBaseEvent().kCloseAllPanel)
        CommonTip:showTip('新的一天开始了，数据已更新，\n请尝试重进活动~')
    end
end

function ColorfulStarWinRepeatManager:onPassActEnd()
    local observerNum = self:getObserverNum()
    if observerNum > 0 then
        self:notify(self:getBaseEvent().kCloseAllPanel)
        CommonTip:showTip(self.meta.ACT_CH_NAME .. '活动已结束!')
    end
end

function ColorfulStarWinRepeatManager:loadRes(delegate)
    local successCallback = delegate.successCallback
    local failCallback = delegate.failCallback
    local resList = delegate.resList
    if EnvUtil and EnvUtil:isMiniGame() then
        _G.amfBean("AssetsUtil"):loadMiniFiles(resList):next(successCallback, failCallback)
    else
        safeRunCall(successCallback)
    end
end

function ColorfulStarWinRepeatManager:unloadRes(resList)
    if EnvUtil:isMiniGame() then
        _G.amfBean("AssetsUtil"):unloadRes(resList)
    else
        for i, v in ipairs(resList) do
            if string.find(v, ".plist") then
                UICreateUtil:unloadPlist(v)
            end
        end
    end
end

function ColorfulStarWinRepeatManager:isEnabled()
    if not self:curLevelTypeIsSupport() then
        return false
    end
    if not FeatureSwitch:isOpen(FeatureSwitch.Type.COLORFUL_STAR_WIN_REPEAT) then return end
    if self:getData():isInMainTime() then
        return true
    else
        return false
    end
end

function ColorfulStarWinRepeatManager:curLevelTypeIsSupport()
    --非满级 或者 （满黄满彩） 不支持
    if _G.amfBean("UserStateManager"):isFMJ() or _G.amfBean("UserStateManager"):isColorfulStarFull() then
        return false
    end
    return true
end

function ColorfulStarWinRepeatManager:fromServer(data, config)
    self:getData():fromServer(data, config)
end

function ColorfulStarWinRepeatManager:onActEnterMainScene(data)
    if data.isFirstEnter then return end

    self:refreshActIcon()
end

function ColorfulStarWinRepeatManager:refreshActIcon()
end

function ColorfulStarWinRepeatManager:isLevelSupport(levelId, levelScene, startLevelType)
    if not self:isEnabled() then
        return false
    end

    if not self:curLevelTypeIsSupport() then
        return false
    end
    startLevelType = startLevelType or UBFStartLevelType.kNormal
    if startLevelType == UBFStartLevelType.kAskForHelp then
        return false
    end

    local isMainLevel = UBFLevelSceneFunc:isMainLevel(levelScene)
    local levelAreaManager = _G.amfBean("LevelAreaManager")
    local scoreRef = levelAreaManager:getUserScore(levelId, levelScene)
    local oldStar = scoreRef and scoreRef.star or 0
    return isMainLevel and oldStar < 4
end

function ColorfulStarWinRepeatManager:getWinDataList()
    local winDataTable = {}
    for i = 1, 5 do
        local flowerData = self:getData():getWinDataByLevel(i)
        winDataTable[i] = flowerData
    end
    return winDataTable
end

function ColorfulStarWinRepeatManager:getWinningCount()
    if not self:isEnabled() then return 0 end
    return self:getData():getCurWinNum()
end

function ColorfulStarWinRepeatManager:showMainPanel(closeCallback, extra, fromType)
    if self:isEnabled() then
        if extra == nil then
            extra = {}
            extra.showBtn = true
        end
        self.dcUtil:sendDC("fulllevel_win", "main_panel_show",
            { t1 = fromType, fulllevel_win_num = self:getData():getCurWinNum() })
        local MainPanelVM = require 'amf.feature.winningstreak.module.colorfulstar.view.MainPanelVM'
        local panel = MainPanelVM:create({ endCallback = closeCallback, extra = extra })
        self.panelPlug:managePanelVM(panel)
        panel:popout()
    else
        safeRunCall(closeCallback)
    end
end

function ColorfulStarWinRepeatManager:managePanelVM(vm)
    self.panelPlug:managePanelVM(vm)
end

function ColorfulStarWinRepeatManager:openFarmStarPanel()
    self:notify(self:getBaseEvent().kCloseAllPanel)
    _G.amfBean("FarmLevelManager"):openFarmStarPanel(nil, FarmConst.FarmStarTag.MAIN_COLORFUL_LEVEL)
end

function ColorfulStarWinRepeatManager:sendDC(category, sub_category)
    self.dcUtil:sendDC(category, sub_category)
end

function ColorfulStarWinRepeatManager:saveFlagToLocalByKey(key, needTime, value, needActStartTimeCheck)
    if needActStartTimeCheck == nil then needActStartTimeCheck = true end
    self:getData():saveFlagToLocalByKey(key, needTime, value, needActStartTimeCheck)
end

function ColorfulStarWinRepeatManager:getFlagFromLocalByKey(key, needTime, needActStartTimeCheck)
    if needActStartTimeCheck == nil then needActStartTimeCheck = true end
    return self:getData():getFlagFromLocalByKey(key, needTime, needActStartTimeCheck)
end

-- 本地缓存int
function ColorfulStarWinRepeatManager:saveFlagToLocalByKeyInt(key, needTime, value, needActStartTimeCheck)
    self:getData():saveFlagToLocalByKeyInt(key, needTime, value, needActStartTimeCheck)
end

function ColorfulStarWinRepeatManager:getFlagFromLocalByKeyInt(key, needTime, needActStartTimeCheck, defaultValue)
    return self:getData():getFlagFromLocalByKeyInt(key, needTime, needActStartTimeCheck, defaultValue)
end

-- 本地缓存str
function ColorfulStarWinRepeatManager:saveFlagToLocalByKeyStr(key, needTime, value, needActStartTimeCheck)
    self:getData():saveFlagToLocalByKeyStr(key, needTime, needActStartTimeCheck)
end

function ColorfulStarWinRepeatManager:getFlagFromLocalByKeyStr(key, needTime, needActStartTimeCheck)
    return self:getData():getFlagFromLocalByKeyStr(key, needTime, needActStartTimeCheck)
end

function ColorfulStarWinRepeatManager:getEndTime()
    return self:getData():getEndTime()
end

function ColorfulStarWinRepeatManager:getNameCN()
    return self.meta.ACT_CH_NAME
end

function ColorfulStarWinRepeatManager:onActCreateResumePanel(evt)
    local data = evt:getData()
    if not self:isEnabled(false) then return end
    if not UBFLevelSceneFunc:isMainLevel(data.levelScene) then return false end
    if not self:isLevelSupport( data.levelId, data.levelScene ) then return false end

    local light = self:getWinningCount()
    if light and light >= 1 then 
        local actInfo = {}
        actInfo.actId = self.actId
        actInfo.winNum = light
        actInfo.showStr = "当前" .. tostring(light) .. "连胜"
        actInfo.priority = 1
        table.insert(data.outData.winState, actInfo)
    end
end

function ColorfulStarWinRepeatManager:onActCrashResumeFailedPopPanel(evt)

    local data = evt.data
    if not self:isEnabled(false) then return end
    if not data or not data.json then return end

    local breakWinNames = data.breakWinNames
    local actIds = data.actIds

    --闪退恢复失败弹板
    local jsonInfo = data.json[''..self.actId]
    if jsonInfo and jsonInfo.curWinNum and jsonInfo.curWinNum > 0  then 
        table.insert(breakWinNames, self.showName )
        table.insert(actIds, self.actId )
    end
end

-- function ColorfulStarWinRepeatManager:onActCrashResumeBeforePopPanelConfirm(evt)
--     --强行断连胜
--     local data = evt.data
--     if not self:isEnabled(false) then return end

--     local actInfos = data.actInfos
--     for i,v in ipairs(actInfos) do
--         if v.actId == self.actId then
--             self:getData():updateWinNum(0)
--             break
--         end
--     end
-- end

function ColorfulStarWinRepeatManager:onActEnterStage4(evt)
    -- 新关不弹
    if _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then
		return false
	end

    if _G.amfBean("ServerCacheManager"):hasGuideFlag(GuideFlagConst.WIN_STREAK_FMJ_MJ) then
		return 
	end

    if not self:isEnabled() then return end

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.COLORFUL_WIN_GUIDE)
    end

    local creator = function()
        if _G.amfBean("ServerCacheManager"):hasGuideFlag(GuideFlagConst.WIN_STREAK_FMJ_MJ) then
            safeRunCall(onHandleOver)
            return 
        end
        
		self:showMainPanel(onHandleOver)
    end

	_G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.COLORFUL_WIN_GUIDE, creator)
end
return ColorfulStarWinRepeatManager
