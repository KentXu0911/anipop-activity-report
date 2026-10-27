local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local MainSceneEventCenter = require "amf.feature.mainscene.core.event.MainSceneEventCenter"
local PassDayTimer = require "amf.script.tool.timer.PassDayTimer"
require "amf.middleware.autopop.config.AutoPopupConst"

local Manager = class("LuckyFarmStarManager", BaseFeatureManager)

local ACTIVITY_END_TIP = "活动已结束!"

function Manager:_getConstPath()
    return "amf.feature.localactivity.luckyfarmstar.const.Const"
end

function Manager:_getModelPath()
    return "amf.feature.localactivity.luckyfarmstar.model.Model"
end

function Manager:_getExtraPlugsConfigList()
    return {
        {
            key = "Panel",
        },
        {
            key = "AutoPop",
        },
        {
            key = "DC",
            path = {
                plugPath = "amf.feature.localactivity.luckyfarmstar.plug.DCPlug",
            },
        },
    }
end

function Manager:dcPlug()
    return self:_getPlug("DC")
end

function Manager:dcNoticePanelShow(panelId, noticeType)
    self:dcPlug():dcNoticePanelShow(panelId, noticeType)
end

function Manager:_getAutoPopConfigList()
    local PopStage = AutoPopupConst.PopStage
    return {
        {
            -- 仅场景2；活动类中位于超级魔力鸟复活卡之前；每期一次由 noticeDisplayedEndTime 控制；打开统一通知面板。
            checkPoint = PopupCheckPoint.LUCKY_FARM_STAR_NOTICE,
            stages = { PopStage.STAGE_TWO },
            check = function()
                return self:canPopNotice()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:tryPopNotice(onPopOver)
                end
            end,
        },
    }
end

function Manager:_init()
    self.actPlug:registerActInfoUpdate("onActInfosUpdate")
    _G.amfEC:registerNormal(NormalEvent.PASS_DAY, self.onPassDay, self)
    MainSceneEventCenter:register(
        MainSceneEvent.Play.HANDLE_PASS_LEVEL,
        self.onHandlePassLevel,
        self,
        MSP.PassLevel.LUCKY_FARM_STAR_NOTICE
    )
    self:getModel():syncActInfo(self.actPlug and self.actPlug:getActInfo() or nil)
    self:refreshEndTimeCallback()
end

function Manager:onPassDay()
    self:getModel():resetLadybugReceivedNum()
end

function Manager:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
end

function Manager:isStarBuffBonusEnabled()
    local model = self:getModel()
    return self:isUserFullLevel()
        and model:isDataEnabled()
        and model:getLadybugBuffNum() > 0
end

function Manager:isStarWandBonusEnabled()
    local model = self:getModel()
    return self:isUserFullLevel()
        and model:isDataEnabled()
        and model:getScepterNum() > 0
end

function Manager:syncActInfo(actInfo)
    self:getModel():syncActInfo(actInfo)
    self:refreshActivity()
end

function Manager:refreshActivity()
    self:refreshEndTimeCallback()
    self:refreshStarWandState()
    self:onActivityUIStateChanged()
end

function Manager:onActInfosUpdate(event)
    local data = event and event:getData() or {}
    if data.fromServer ~= true then
        return
    end
    local actInfos = data.actInfos or {}
    self:syncActInfo(actInfos[tostring(self:getConst().actId)])
end

function Manager:getStarBuffBonusNum()
    if not self:isStarBuffBonusEnabled() then
        return 0
    end
    return self:getModel():getLadybugBuffNum()
end

function Manager:getStarBuffReceivedNum()
    if not self:isStarBuffBonusEnabled() then
        return 0
    end
    return math.min(self:getStarBuffBonusNum(), self:getModel():getLadybugReceivedNum())
end

function Manager:addStarBuffReceivedNum(num)
    self:getModel():addLadybugReceivedNum(num)
end

function Manager:getRemainingStarBuffBonusNum()
    return math.max(0, self:getStarBuffBonusNum() - self:getStarBuffReceivedNum())
end

function Manager:getAdditionalStarBuffNums()
    local bonusNum = self:getRemainingStarBuffBonusNum()
    if bonusNum <= 0 then
        return nil
    end
    return {
        [self:getConst().ACTIVITY_KEY] = bonusNum,
    }
end

function Manager:getStarBuffPanelInfo()
    if not self:isStarBuffBonusEnabled() then
        return
    end

    local activityNum = self:getRemainingStarBuffBonusNum()
    if activityNum <= 0 then
        return
    end

    return {
        num = activityNum,
        endTimeInSec = self:getEndTimeInSec(),
    }
end

function Manager:createStarBuffBubbleSign(signName)
    if signName ~= "greenImg" and signName ~= "orangeImg" then
        return nil
    end

    if not self._starBuffSignBuilder then
        local UIBuilder = require "amf.middleware.ui.export.UIBuilder"
        local uiData = require "amf.feature.localactivity.luckyfarmstar.view.uisource.LuckyFarmStarPanel_UI"
        self._starBuffSignBuilder = UIBuilder.new(uiData)
    end

    local isLuckySign = signName == "greenImg"
    local title = self._starBuffSignBuilder:createChild(isLuckySign and "titleText_1" or "titleText_2")
    if not title then return nil end

    local frameName = isLuckySign
        and "LuckyFarmStar1/LuckyFarmStar2/group_4"
        or "LuckyFarmStar1/LuckyFarmStar2/group_3"
    local sign = Sprite:createWithSpriteFrameName(frameName)
    if not sign then
        title:dispose()
        return nil
    end
    sign:addChild(title)
    sign:setPositionXY(-2, 68)
    sign:setScale(0.833)
    return sign
end

function Manager:onActivityUIStateChanged()
    if self:getModel():isDataEnabled() then
        return
    end

    if self:closeAllPanels() then
        CommonTip:showTip(ACTIVITY_END_TIP)
    end
end

function Manager:closeAllPanels()
    local observerNum = self:getObserverNum()
    self:notify(self:getBaseEvent().kCloseAllPanel)
    return observerNum > 0
end

function Manager:getScepterNum()
    if not self:isStarWandBonusEnabled() then
        return 0
    end
    return self:getModel():getScepterNum()
end

function Manager:getStarWandPanelExtraLevelNum()
    if not self:isStarWandBonusEnabled() then
        return 0
    end

    local wandManager = self:getStarWandBuffManager()
    local module = wandManager and wandManager:getModuleByKey(self:getConst().ACTIVITY_KEY)
    return module and module:getRecommendMaxNum() or 0
end

function Manager:fillStarWandPanelSource(event)
    local data = event and event.getData and event:getData() or event
    if not data then
        return
    end
    local levelId = data.levelId or data.current_stage
    local levelScene = data.levelScene or data.levelscene or data.level_scene
    if self:isLuckyFarmStarWandLevel(levelId, levelScene) then
        data.panel_source = 5
    end
end

function Manager:onActDcStageCommon(event)
    local data = event and event:getData() or nil
    if data and data.category == "stage" and data.sub_category == "start_show" then
        self:fillStarWandPanelSource(data)
    end
end

function Manager:onActDcStageStart(event)
    self:fillStarWandPanelSource(event)
end

Manager.onActDcStageQuit = Manager.onActDcStageStart
Manager.onActDcStageEnd = Manager.onActDcStageStart

function Manager:getEndTimeInSec()
    return self:getModel():getEndTimeInSec()
end

function Manager:isUserFullLevel()
    local userStateManager = _G.amfBean("UserStateManager")
    return userStateManager and not userStateManager:isFMJ() or false
end

function Manager:hasNoticeDisplayed()
    local endTime = self:getEndTimeInSec()
    return endTime > 0 and self:getModel():getNoticeDisplayedEndTime() == endTime
end

function Manager:isNoticeUIReady()
    return true
end

function Manager:canPopNotice()
    return (self:isStarBuffBonusEnabled() or self:isStarWandBonusEnabled())
        and not self:hasNoticeDisplayed()
        and self:isNoticeUIReady()
end

function Manager:createNoticePanelVM(closeCallback)
    local items = {}
    local noticeType = 0
    local starBuffNum = self:getStarBuffBonusNum()
    local scepterNum = self:getScepterNum()
    if starBuffNum > 0 then
        table.insert(items, {
            itemId = AMFPropId.STARBUFF,
            num = starBuffNum,
        })
        noticeType = noticeType + 1
    end
    if scepterNum > 0 then
        table.insert(items, {
            itemId = AMFPropId.FULL_STAR_BUFF_ENERGY,
            num = scepterNum,
        })
        noticeType = noticeType + 2
    end

    local PanelVM = require "amf.feature.localactivity.luckyfarmstar.view.LuckyFarmStarPanelVM"
    return PanelVM:create({
        mgr = self,
        items = items,
        noticeType = noticeType,
        endTime = self:getEndTimeInSec(),
        closeCallback = closeCallback,
    })
end

function Manager:tryPopNotice(closeCallback)
    if not self:canPopNotice() then
        safeRunCall(closeCallback)
        return false
    end

    local panelVM = self:createNoticePanelVM(closeCallback)
    if not panelVM or panelVM.isDisposed then
        safeRunCall(closeCallback)
        return false
    end
    self:getModel():setNoticeDisplayedEndTime(self:getEndTimeInSec())
    self.panelPlug:managePanelVM(panelVM)
    panelVM:popout()
    return true
end

function Manager:onHandlePassLevel(evt)
    local data = evt and evt:getData() or {}
    local levelAreaManager = _G.amfBean("LevelAreaManager")
    local globalMaxLevel = levelAreaManager and levelAreaManager:getGlobalMaxLevel() or 0
    local reachedFullLevel = UBFLevelSceneFunc:isMainLevel(data.levelScene)
        and data.isFirstPassLevel == true
        and tonumber(data.passedLevelId) == tonumber(globalMaxLevel)
        and self:isUserFullLevel()

    if not reachedFullLevel or not self:canPopNotice() then
        evt:redeliver()
        return
    end

    _G.amfBean("AutoPopupMgr"):blockPassLevelSkip()
    self:tryPopNotice(function()
        evt:redeliver()
    end)
end

function Manager:getStarWandBuffManager()
    return _G.amfBean("StarWandBuffManager")
end

function Manager:isLuckyFarmStarWandLevel(levelId, levelScene)
    local wandManager = self:getStarWandBuffManager()
    if not wandManager or not levelId or levelScene == nil then
        return false
    end

    levelId = tonumber(levelId) or levelId
    levelScene = tonumber(levelScene) or levelScene
    local recommendLevels = wandManager:getModel():getRecommendLevelsByKey(self:getConst().ACTIVITY_KEY)
    return table.exist(recommendLevels[levelScene] or {}, levelId)
end

function Manager:refreshStarWandState()
    local wandManager = self:getStarWandBuffManager()
    if not wandManager or not wandManager.hasLightStart then
        return
    end

    if self:isStarWandBonusEnabled() then
        wandManager:tryRecommendLevelByKey(self:getConst().ACTIVITY_KEY, true)
    else
        wandManager:updateLevelMapForMainScene()
        wandManager:updateMainScene()
    end
end

function Manager:registerEndTimeCallback()
    local endTime = self:getEndTimeInSec()
    if endTime <= 0 or TimeKit:timeInSec() >= endTime then
        return
    end

    local callback
    callback = function()
        if self._endTimeCallback ~= callback then return end
        self._registeredEndTime = nil
        self._endTimeCallback = nil
        self:refreshActivity()
    end
    self._registeredEndTime = endTime
    self._endTimeCallback = callback
    PassDayTimer:registerEndTimeCallback(endTime, callback)
end

function Manager:refreshEndTimeCallback()
    self:unregisterEndTimeCallback()
    if self:getModel():isDataEnabled() then
        self:registerEndTimeCallback()
    end
end

function Manager:unregisterEndTimeCallback()
    if self._registeredEndTime and self._endTimeCallback then
        PassDayTimer:unregisterEndTimeCallback(self._registeredEndTime, self._endTimeCallback)
    end
    self._registeredEndTime = nil
    self._endTimeCallback = nil
end

function Manager:onSystemEnterForeground()
    self:refreshActivity()
end

return Manager
