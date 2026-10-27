local MainSceneButtonManager = class("MainSceneButtonManager")
local MainSceneButtonDC = require("amf.feature.mainscenebutton.dc.MainSceneButtonDC")
local MainSceneButtonEventCenter = require "amf.feature.mainscenebutton.event.MainSceneButtonEventCenter"
local ButtonConst = require("amf.feature.mainscenebutton.const.ButtonConst")
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local FullStarLevelLibEventCenter = require("amf.feature.fullstarlevellib.event.FullStarLevelLibEventCenter")
local MainSceneEventCenter = require 'amf.feature.mainscene.core.event.MainSceneEventCenter'
require 'amf.feature.mainscene.core.event.MainSceneEvent'
require "amf.middleware.autopop.config.AutoPopupCheckPoints"

local PASS_LEVEL_SKIP_ENTRY = "main_scene_pass_level_animation"
local PASS_LEVEL_BUTTON_SKIP_MAINTENANCE = "Skip_Scene3_v1"
local PASS_LEVEL_SKIP_ALLOWED_POPUPS = {
    -- 自动跳下一关属于过关后的预期流程，可与过关动画共存。
    [PopupCheckPoint.EXIT_LEVEL_JUMP] = true,
}


function MainSceneButtonManager:setUserStateManager(userStateManager)
    self._userStateManager = userStateManager
end

function MainSceneButtonManager:setMetaManager(metaManager)
    self._metaManager = metaManager
end

function MainSceneButtonManager:setFullStarLevelLibManager(fullStarLevelLibManager)
    self._fullStarLevelLibManager = fullStarLevelLibManager
end

function MainSceneButtonManager:setLevelUnLockManager(levelUnLockManager)
    self._levelUnlockManager = levelUnLockManager
end

function MainSceneButtonManager:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
    autoPopupMgr:registerInterruptibleEntry(PASS_LEVEL_SKIP_ENTRY, {
        popupCheckPoint = PopupCheckPoint.PLAY_LEVEL_BACK,
        allowedPopupCheckPoints = PASS_LEVEL_SKIP_ALLOWED_POPUPS,
        isEnabled = function(levelPlayInfo)
            return levelPlayInfo.isWin
                and self:isPassLevelButtonSkipEnabled()
        end,
        hitTest = function(worldPos)
            return self:isButtonTouchTarget(worldPos)
        end,
        onInterrupt = function()
            MainSceneEventCenter:dispatch(MainSceneEvent.Action.SKIP_PASSLEVEL_ANIMATION)
        end,
    })
end

function MainSceneButtonManager:setServerCacheManager(serverCacheManager)
    self._serverCacheManager = serverCacheManager
end

function MainSceneButtonManager:initialize()
    self:registerEvents()
    self:registerHaptics()
    self:initFileObj()
end

function MainSceneButtonManager:initFileObj()
    self.fileObj = LocalDB:createFileObject("main_scene_button_manager")
end

function MainSceneButtonManager:getConst()
    return ButtonConst
end

function MainSceneButtonManager:getDC()
    return MainSceneButtonDC
end

-- 满级部分是否开启
function MainSceneButtonManager:isFullLevelEnabled()
    return true
end

-- 活动部分是否开启
function MainSceneButtonManager:isActivityEnabled()
    -- 全开
    return true
end

function MainSceneButtonManager:isEnabled()
    if EnvUtil:isMiniGame() then
        if MaintenanceManager:getInstance():isEnabledInGroup("PassLevelBtn_Minitest", "OFF") then
            return false
        end
    end

    return true
end

function MainSceneButtonManager:registerEvents()
    local UnlockEventCenter = require "amf.feature.mainscene.module.areaunlock.event.UnlockEventCenter"
    local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
    local MainSceneEventCenter = require 'amf.feature.mainscene.core.event.MainSceneEventCenter'
    AutoPopEventCenter:registerGlobal(NormalEvent.NO_PANEL_ON_SCENE, self._onPanelRemove, self)
    UnlockEventCenter:register(UnlockAreaEvent.Unlock.UNLOCK_EVENT, self._onReceiveUnlockEvent, self)
    IconEventCenter:register(IconEvent.ICON_SYSTEM_READY, self._onIconSystemReady, self)
    MainSceneButtonEventCenter:register(MainSceneButtonEvent.UPDATE, self.onButtonRefresh, self)
    MainSceneEventCenter:register(MainSceneEvent.Trunk.LEVEL_NODE_TOUCHED, self.onLevelNodeTouched, self)
    FullStarLevelLibEventCenter:register(FullStarLevelLibEvent.FULL_STAR_LEVEL_LIB_FIRST_UPDATE, self.onButtonRefresh, self)
    MainSceneButtonEventCenter:registerFeature(self)
    MainSceneButtonEventCenter:registerSystem(self)
end

function MainSceneButtonManager:playHaptic()
    if self.haptic then
        HapticsManager:playInActScene(self.haptic)
    end
end

function MainSceneButtonManager:registerHaptics()
    if self.haptic then return end
    local params = require("amf.feature.mainscenebutton.haptics.ButtonHaptics")
    self.haptic = params
end

function MainSceneButtonManager:isMainSceneEnabled()
    local scene = Director:sharedDirector():getRunningSceneLua()
    if scene and scene:isScene("MainScene") then
        return true
    end
    return false
end

--scoreBuff 1.1, 1.2之类的
function MainSceneButtonManager:createScoreBuff(scoreNum)
    local icon = Sprite:createWithSpriteFrameName("item/frame/item_10188")
    icon:setScale(0.25)
    icon:setAnchorPoint(ccp(0.5,0.5))

    local iconSize = 128
    local score = TTFLabel:createAnimalYH("分数", 32)
    score:setAnchorPoint(ccp(0.5, 0.5))
    score:setPositionXY(iconSize/2 + 5, iconSize/2 + 9)
    score:setTextColor(hex2ccc4("B2560DFF"))
    icon:addChild(score)

    local eps = 1e-9
    local numLabel = TTFLabel:createAnimalYH(math.floor(scoreNum * 100 + eps) .. "%", 36)
    numLabel:setTextColor(hex2ccc4("FFFB00FF"))
    numLabel:enableOutline(hex2ccc4("B1550DFF"), 3)
    numLabel:setAnchorPoint(ccp(0.5, 0.5))
    numLabel:setPositionXY(iconSize / 2 + 7, iconSize / 2 - 30)
    icon:addChild(numLabel)
    return icon
end

function MainSceneButtonManager:resolveButtonConfig(config)
    local data = {}
    for k,v in ipairs(config) do
        if not data[v.uniqueId] then
            data[v.uniqueId] = v
            if v.uniqueId == _G.BuffTypeConfig.SCORE_BUFF then
                data[v.uniqueId].iconCreator = function()
                    return self:createScoreBuff(data[v.uniqueId].rate)
                end
            end
        else
            if v.uniqueId == _G.BuffTypeConfig.SCORE_BUFF then
                data[v.uniqueId].rate = v.rate + data[v.uniqueId].rate - 1
                data[v.uniqueId].endTime = math.min(v.endTime, data[v.uniqueId].endTime)
                data[v.uniqueId].iconCreator = function()
                    return self:createScoreBuff(data[v.uniqueId].rate)
                end
                data[v.uniqueId].actId = v.actId .. "_" .. data[v.uniqueId].actId
            end
        end
    end

    local retData = {}
    -- 关卡库筛除加分
    for k,v in pairs(data) do
        if k == _G.BuffTypeConfig.SCORE_BUFF and self._fullStarLevelLibManager:canPlay() then
        -- 筛掉时间为0的,去除鬼畜
        elseif v.endTime > TimeKit:timeInSec() then
            table.insert(retData, v)
        end
    end
    return retData
end

function MainSceneButtonManager:getExtraModuleConfig()
    local config
    for k,v in ipairs(ButtonConst.extraModuleConfig) do
        local manager = _G.amfBean(v.managerName)
        if manager and manager.getMainSceneButtonModuleConfig then
            local tmpconfig = manager:getMainSceneButtonModuleConfig()
            if tmpconfig and not table.isEmpty(tmpconfig) then
                config = tmpconfig
                break
            end
        end
    end
    return config
end

function MainSceneButtonManager:getButtonConfig(uniqueId)
    local config = {}
    for k,v in ipairs(ButtonConst.buttonConfig) do
        local manager = _G.amfBean(v.managerName)
        if manager and manager.getMainSceneButtonShowConfig then
            local tmpconfig = manager:getMainSceneButtonShowConfig()
            if tmpconfig and not table.isEmpty(tmpconfig) then
                if tmpconfig.uniqueId then
                    if not uniqueId or uniqueId == tmpconfig.uniqueId then
                        table.insert(config, tmpconfig)
                    end
                else
                    for k1,v1 in ipairs(tmpconfig) do
                        if not uniqueId or v1.uniqueId == uniqueId then
                            table.insert(config, v1)
                        end
                    end
                end
            end
        end
    end
    local retConfig = self:resolveButtonConfig(config)

    table.sort(retConfig, function(a, b)
        return a.endTime < b.endTime
    end)

    return retConfig
end

function MainSceneButtonManager:onActBeforeStartLevel(evt)
    if self.buttonVM then
        self.buttonVM:pauseSchedule()
    end
end

function MainSceneButtonManager:onActEnterMainScene(event)
    local data = event:getData()
    local firstEnter = data.firstEnter
    self:tryCreateButton()
    if not firstEnter then
        if self.buttonVM then self.buttonVM:resumeSchedule() end
        self:tryRefreshButton()
    end

    self:tryAddAutoPop()
end

function MainSceneButtonManager:onSystemEnterForeground(event)
    self:tryAddAutoPop()
    self:playGuideHandAnim()
end

-- 权杖强弹
function MainSceneButtonManager:canPlayStarWandAutoPop()
    if self._autoPopupMgr:ignoreForTopLevelPlayer() then -- 周五晚19:00~23:00，对头部top30打新关的玩家屏蔽
        return false
    end
    if self._fullStarLevelLibManager:canPlay() then return false end
    local flag1 = self:isStarWandCanShow()
    local key = "StarWandAutoPop" .. self._levelUnlockManager:getLocalTopLevel(true)
    local flag2 = self._autoPopupMgr:getPermanentShowNum(key) < 1
    return flag1 and flag2
end

function MainSceneButtonManager:sendStarWandAutoPop()
    local key = "StarWandAutoPop" .. self._levelUnlockManager:getLocalTopLevel(true)
    self._autoPopupMgr:sendPermanentData(key)
end

function MainSceneButtonManager:tryAddAutoPop()
    if not self.buttonVM then return end
    if self:canPlayStarWandAutoPop() then
        self._autoPopupMgr:addPopupConfig(PopupCheckPoint.MAIN_SCENE_BUTTON, function()
            self:playStarWandAutoPop()
        end)
    end
end

function MainSceneButtonManager:playStarWandAutoPop()
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.MAIN_SCENE_BUTTON)
    end

    if not self.buttonVM then
        safeRunCall(onHandleOver)
        return
    end

    if not self:canPlayStarWandAutoPop() then
        safeRunCall(onHandleOver)
        return
    end
    local curScene = Director:sharedDirector():getRunningSceneLua()
    if not curScene then
        safeRunCall(onHandleOver)
        return
    end

    self:playStarWandFly(curScene, function()
        self:sendStarWandAutoPop()
        if self._serverCacheManager:hasGuideFlag(GuideFlagConst.MAINSCENE_BUTTON_GUIDE) then
            safeRunCall(onHandleOver)
        else
            self._serverCacheManager:setGuideFlag(GuideFlagConst.MAINSCENE_BUTTON_GUIDE)
            self.buttonVM:playStarWandGuide(function()
                MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.SHOW_STAR_WAND_GUIDE, {
                    callback = onHandleOver
                })
            end)
        end
    end)
end

function MainSceneButtonManager:playStarWandFly(curScene, callback)
    if not self.buttonVM or not self.buttonVM.view or not self.buttonVM.view.starWandIcon then
        safeRunCall(callback)
        return
    end

    self.buttonVM:setButtonEnabled(false)
    local darkLayer = UICreateUtil:createDarkLayer(0)
    curScene:addChild(darkLayer, SceneLayerShowKey.TOP_LAYER)
    local oldParent = self.buttonVM.view:getParent()
    LayoutUtil:changeParentNoBack(self.buttonVM.view, darkLayer)

    darkLayer:runAction(CCFadeTo:create(0.5, 150))

    local icon = UICreateUtil:createSpriteFile("amf/mainscenebutton/materials/daquanzhang.png")
    icon:setPositionXY(360, 640)
    darkLayer:addChild(icon)

    local quanzhangtexiao = UICreateUtil:createSpine("amf/mainscenebutton/spine/quanzhang_tx.skel", nil, nil, nil, true)
    quanzhangtexiao:setPositionXY(360, 640)
    darkLayer:addChild(quanzhangtexiao)
    quanzhangtexiao:playOnceAndDispose("a1")

    icon:setScale(0.5)
    icon:runAction(ActionUtil:sequence({
        CCEaseSineOut:create(CCScaleTo:create(2/15, 1.1, 1.1)),
        CCEaseSineInOut:create(CCScaleTo:create(1/10, 1, 1)),
        CCDelayTime:create(13/30),
        CCEaseSineIn:create(CCScaleTo:create(10/30, 0.3, 0.3)),
        CCCallFunc:create(function()
            icon:setScale(0)
            self.buttonVM.view:playStarWandIconAnim()
        end),
        CCDelayTime:create(15/30),
        CCCallFunc:create(function()
            if icon and not icon.isDisposed then
                icon:removeFromParentAndCleanup(true)
            end
            LayoutUtil:changeParentNoBack(self.buttonVM.view, oldParent)
            darkLayer:removeFromParentAndCleanup(true)
            self.buttonVM:setButtonEnabled(true)
            safeRunCall(callback)
        end)
    }))
    local pos = self.buttonVM.view.starWandIcon:getPositionInWorldSpace()
    local endPos = darkLayer:convertToNodeSpace(ccp(pos.x + 30, pos.y - 18))
    icon:runAction(ActionUtil:sequence({
        CCDelayTime:create(13/30),
        CCEaseSineIn:create(self:getBezierAction(icon:getPosition(), endPos))
    }))
end

function MainSceneButtonManager:playFullStarLevelLibAnim(startPos, done)
    local scene = Director:sharedDirector():getRunningSceneLua()
    if not scene then
        safeRunCall(done)
        return
    end
    if not self.buttonVM then
        safeRunCall(done)
        return
    end

	self.buttonVM.view:playFullStarLevelLibAnim(done)

    local anim = UICreateUtil:createSpine("amf/mainscenebutton/spine/wenzi_fei.skel", nil, nil, nil, true)
    scene:addChild(anim, SceneLayerShowKey.TOP_LAYER)
    anim:setPosition(startPos)
    anim:playOnceAndDispose("in")

    local anim2 = UICreateUtil:createSpine("amf/mainscenebutton/spine/buff_in_vfx.skel", nil, nil, nil, true)
    anim2:playOnceAndDispose("in_suiji")
    anim2:setPosition(startPos)
    scene:addChild(anim2, SceneLayerShowKey.TOP_LAYER)
end

function MainSceneButtonManager:getBezierAction(startPos, endPos)
    local p1, p2

    p1 = ccp(0.4 * (endPos.x - startPos.x), -0.2 * (endPos.y - startPos.y) )
    p2 = ccp(0.9 * (endPos.x - startPos.x), 0.5 * (endPos.y - startPos.y) )

    local bezierConfig = ccBezierConfig:new()
    bezierConfig.controlPoint_1 = ccp(startPos.x +  p1.x, startPos.y +  p1.y)
    bezierConfig.controlPoint_2 = ccp(startPos.x +  p2.x, startPos.y +  p2.y)
    bezierConfig.endPosition = ccp(endPos.x, endPos.y)
    local object = CCEaseSineIn:create(CCBezierTo:create(17/30, bezierConfig))
    return object
end

function MainSceneButtonManager:_onIconSystemReady()
    self:tryCreateButton()
end

function MainSceneButtonManager:_onPanelRemove()
    if self:isMainSceneEnabled() then
        self:tryRefreshButton()
    else
        self:tryDeleteButton()
    end
end

function MainSceneButtonManager:_onReceiveUnlockEvent(event)
    local params = event:getData()
    if params.evt == UnlockAreaEvent.Unlock.UNLOCK_SUCCESS then
        self:tryCreateButton()
        self:tryRefreshButton()
    end
end

function MainSceneButtonManager:loadInputRes(files)
    local deferred = require "amf.script.sugar.deferred"
    local d = deferred.new()
    _G.amfBean("AssetsUtil"):loadMiniFiles(files, true):next(function()
        d:resolve()
    end, function()
        d:reject()
    end)
    return d
end

function MainSceneButtonManager:tryCreateButton()
    if not self:isEnabled() then return end
    if not self:isMainSceneEnabled() then return end
    if self.buttonVM and not self.buttonVM.isDisposed then return end
    if self.isCreating then return end

    self.isCreating = true
    _G.amfBean("AssetsUtil"):loadMiniLabels({"MainSceneButton"}):next(function()
        self.isCreating = false
        if not self.buttonVM or self.buttonVM.isDisposed then
            local ButtonVM = require("amf.feature.mainscenebutton.view.ButtonVM")
            self.buttonVM = ButtonVM:create()
            local iconLayer = _G.amfBean("IconManager"):getIconLayer()
            if not iconLayer then return end

			iconLayer:addChildAt(self.buttonVM.view, 1)

            self.buttonVM:setScale(0)
            self:refreshButtonPos()

            setTimeOut(function()
                if not self.buttonVM or self.buttonVM.isDisposed then return end
                self:refreshButton()
                self:playGuideHandAnim()
            end, 1)

            -- 经过调查，BottomIconPool使用的是followScreenEdge，
            -- 这块如果想和底边Icon池保持同样距离，变分辨率后相对距离不变，这里也需要用follow
            self.buttonVM.view:followScreenEdge(nil, _G.ScreenEdge.kSAFE_BOTTOM, _G.fullScreenSizeManager)
        end
    end,function()
        self.isCreating = false
    end)
end

function MainSceneButtonManager:tryRefreshButton(onlyRefreshData)
    if not self.buttonVM then return end
    if self.buttonVM.isDisposed then return end
    self:refreshButton(onlyRefreshData)
end

function MainSceneButtonManager:tryDeleteButton()
    if not self:isEnabled() or self:calLevelData() == nil then
        if self.buttonVM and not self.buttonVM.isDisposed then
            self.buttonVM:dispose()
            self.buttonVM = nil
        end
    end
end

--补星权杖推荐的关卡
function MainSceneButtonManager:getStarWandData()
    local levelMap = _G.amfBean("StarWandBuffManager"):getCanUseRecommendLevelsCareFullStar()
    local lvsMain, lvsHide = levelMap[UBFLevelSceneType.kMain] or {},
        levelMap[UBFLevelSceneType.kHide] or {}
    if #lvsMain == 0 then return end
    return lvsMain, lvsHide
end

function MainSceneButtonManager:isStarWandCanShow()
    local lvsMain = self:getStarWandData()
    return lvsMain and _G.amfBean("StarWandBuffManager"):isEnabled()
end

-- 计算关卡推荐数据
function MainSceneButtonManager:calLevelData()
    local fullLevelState = self._userStateManager:getUserSegmentState()
    local levelId, levelFlag, areaLocked, levelScene, showStarWand
    local buttonState
    if self._userStateManager:isFMJ() then
        levelId = _G.getTopLevelId()
        local topPassedMainLevelId = _G.getTopPassedLevelId()
        levelFlag = self._metaManager:getLevelDifficultFlag(levelId, UBFLevelSceneType.kMain)
        areaLocked = levelId == topPassedMainLevelId
        levelScene = UBFLevelSceneType.kMain
        buttonState = ButtonConst.buttonStateConfig.FMJ
    elseif self._fullStarLevelLibManager:canPlay()  then
        levelId = self._fullStarLevelLibManager:getNextLevelId()
        levelFlag = LevelDiffcultFlag.kNormal
        areaLocked = false
        levelScene = UBFLevelSceneType.kFullLevelLibrary
        buttonState = ButtonConst.buttonStateConfig.FSLB
    else
        levelScene = UBFLevelSceneType.kMain
        buttonState = ButtonConst.buttonStateConfig.MJ
        if self:isStarWandCanShow() then
            showStarWand = true
            local lvsMain = self:getStarWandData()
            levelId = lvsMain[1]
            buttonState = ButtonConst.buttonStateConfig.MJSW
        end
        if not levelId then
            local RecommendLevelUtil = require "amf.feature.recommendlevel.RecommendLevelUtil"
            levelId, levelScene = RecommendLevelUtil:getNotFullColorStarLowestLevel()
            if not UBFLevelSceneFunc:isMainLevel(levelScene) then
                return nil
            end
        end
        levelFlag = self._metaManager:getLevelDifficultFlag(levelId, UBFLevelSceneType.kMain)
        areaLocked = false
    end

    -- 取不到关卡，保底删除按钮
    if not levelId then
        return nil
    end

    return {
        levelId = levelId,
        levelFlag = levelFlag,
        areaUnlocked = not areaLocked,
        levelScene = levelScene,
        showStarWand = showStarWand,
        buttonState = buttonState,
        fullLevelState = fullLevelState
    }
end

function MainSceneButtonManager:onButtonRefresh()
    self:tryCreateButton()
    if self.buttonVM and not self.buttonVM.isDisposed then
        self:tryAddAutoPop()
        self:refreshButton()
    end
end

function MainSceneButtonManager:onLevelNodeTouched()
    self:stopGuideHandAnim()
end

function MainSceneButtonManager:refreshButton(onlyRefreshData)
    if self.isLoadingRes then return end

    local levelData = self:calLevelData()
    if levelData == nil then
        self:tryDeleteButton()
        return
    end

    if not self.buttonVM then
        return
    end

    local inputBuff, inputModule

    if self:isActivityEnabled() then
        local moduleConfig = self:getExtraModuleConfig() or {}
        inputModule = moduleConfig

        local nowButtonBuffData = self.buttonVM:getBuffData()
        local nowBuffEnabled = nowButtonBuffData and not table.isEmpty(nowButtonBuffData)
            and nowButtonBuffData.endTime > TimeKit:timeInSec() and nowButtonBuffData.uniqueId ~= inputModule.uniqueId
        if nowBuffEnabled then
            inputModule = nil
        end
        local config = self:getButtonConfig(inputModule and inputModule.uniqueId) or {}
        inputBuff = config[1]
        if nowBuffEnabled then
            for k,v in ipairs(config) do
                if v.uniqueId == nowButtonBuffData.uniqueId then
                    inputBuff = v
                    break
                end
            end
        end

        if inputModule and not table.isEmpty(inputModule) then
            if inputBuff and not table.isEmpty(inputBuff) then
                inputBuff.lightAnim = true
            end
        end
    end

    local function refreshFunc()
        if not self.buttonVM or self.buttonVM.isDisposed then return end
        self.isLoadingRes = false
        self.buttonVM:refreshData(levelData, inputBuff, inputModule)
        if not onlyRefreshData then
            self.buttonVM:refreshView()
        end
    end

    if inputBuff and inputBuff.needLoadRes then
        self.isLoadingRes = true
        self:loadInputRes(inputBuff.needLoadRes):next(refreshFunc, function()
            self.isLoadingRes = false
        end)
    else
        refreshFunc()
    end
end

function MainSceneButtonManager:isRecallEnabled()
    local flag1 = _G.amfBean("RecallAutoStartLevelManager"):canPlayHandAnim()
    local flag2 = self:getRecallHandShowTime() < 3

    return flag1 and flag2
end

function MainSceneButtonManager:getRecallHandShowTime()
    local time = self.fileObj:getValue("saveTime")
    local nowTime = TimeKit:getDayStartTimeByTS(TimeKit:timeInSec())
    if nowTime ~= time then
        return 0
    end

    local count = self.fileObj:getValue("saveCount") or 0
    return count
end

function MainSceneButtonManager:addRecallHandShowTime()
    if self:isRecallEnabled() then
        self.fileObj:setValue("saveTime", TimeKit:getDayStartTimeByTS(TimeKit:timeInSec()))
        local count = self.fileObj:getValue("saveCount") or 0
        self.fileObj:setValue("saveCount", count + 1)
    end
end

function MainSceneButtonManager:playGuideHandAnim()
    if not self.buttonVM then return end
    if _G.getTopLevelId() <= 40 or self:isRecallEnabled() then
        self.buttonVM:startCount()
    else
        self.buttonVM:stopCount()
    end
end

function MainSceneButtonManager:stopGuideHandAnim()
    if not self.buttonVM then return end
    self.buttonVM:stopCount()
end

function MainSceneButtonManager:refreshButtonPos()
    if not self.buttonVM then return end
    if self.buttonVM.isDisposed then return end
    local safeArea = _G.fullScreenSizeManager:getSafeArea()
    local visibleSize = safeArea.size
    local visibleOrigin = safeArea.origin

    local layoutBarWidth = visibleSize.width / 2

    local x = visibleOrigin.x + layoutBarWidth
    -- 距离优化为230
    local y = visibleOrigin.y + 230 + self.buttonVM.view:getContentSize().height / 2

    self.buttonVM:setPositionXY(x, y)
end

function MainSceneButtonManager:dc(sub_category, t1, t2, t3, extra)
    local param = {
        category = "vine",
        sub_category = sub_category,
        t1 = t1,
        t2 = t2,
        t3 = t3,
    }
    for k,v in pairs(extra or {}) do
        param[k] = v
    end
    DcUtil:UserTrack(param)
end

function MainSceneButtonManager:playEffect()
    local filePath = "amf/mainscenebutton/music/normal.mp3"
    GamePlayMusicPlayer.getInstance():playEffect(filePath, nil, false)
end

function MainSceneButtonManager:isButtonTouchTarget(worldPos)
    local button = self.buttonVM and self.buttonVM.view
    if not button or button.isDisposed then
        return false
    end
    return button:isAutoPopupTouchTarget(worldPos)
end

function MainSceneButtonManager:isPassLevelButtonSkipEnabled()
    return MaintenanceManager:getInstance():isEnabledInGroup(
        PASS_LEVEL_BUTTON_SKIP_MAINTENANCE, "ON"
    )
end

function MainSceneButtonManager:onButtonTapped(delegate)
	self._autoPopupMgr:abortInterruptibleEntry(PASS_LEVEL_SKIP_ENTRY)
	if not _G.amfBean("PopoutManager"):haveWindowOnScreen() then
        -- 开始监控从响应点击到打开开始面板的耗时
        UBFPerfMonitor.start("OpenSlp", UBFPerfMonitor.Profile.OPEN_SLP)

        if self._userStateManager:isFMJ() then
            local playLevelContext = PlayLevelContext.new(nil, PlayLevelContext.PlayType.UN_PASSED_MAIN)
            playLevelContext:setAutoUnlock(true)
            playLevelContext:setExtraData({
                from = "MainSceneButton"
            })
            _G.amfTransaction(TransactionEvent.PLAY_LEVEL, playLevelContext)
        -- 关卡库使用关卡库接口
        elseif UBFLevelSceneFunc:isFullLevelLib(delegate.levelScene) then
            self._fullStarLevelLibManager:tryOpenStartPanel(true)
        else
            local playLevelContext = PlayLevelContext.new(delegate.levelId, PlayLevelContext.PlayType.OPEN_SL_PANEL)
            playLevelContext:setAutoUnlock(true)
            playLevelContext:setExtraData({
                from = "MainSceneButton"
            })
            playLevelContext:setTrunkInsight(true)
            playLevelContext:setLevelScene(delegate.levelScene)
            _G.amfTransaction(TransactionEvent.PLAY_LEVEL, playLevelContext)
        end
        self:playHaptic()
        self:playEffect()

        MainSceneButtonDC:sendDC("play_button_click", {
            t1 = delegate.levelFlag,
            t2 = delegate.actId1,
            t3 = delegate.actId2,
            t4 = delegate.buttonState,
            current_stage = delegate.levelId
        })
    end
end

function MainSceneButtonManager:getButtonPosition()
    if self.buttonVM and not self.buttonVM.isDisposed then
        return self.buttonVM.view:getPosition()
    end
    return nil
end

function MainSceneButtonManager:isButtonCreated()
    return self.buttonVM and not self.buttonVM.isDisposed
end

return MainSceneButtonManager
