local SuperMagicBird2024 = class2("SuperMagicBird2024", UBFGameActManager)

-- 与关卡外的桥接类，请统一通过该类的接口访问关卡外内容
require("ubf.UBFActivity.actFolder.SuperMagicBird2024.SmbAmfBridge")

require("ubf.UBFActivity.actFolder.SuperMagicBird2024.SuperMagicBirdBaodi")
require("ubf.UBFActivity.actFolder.SuperMagicBird2024.SuperMagicBirdThrower")

local CollectionEnum = {
	SUPER = "132",
	-- GIFT = "133",
	-- FLOWER = "134",
}

local SLP_ACTIVATION_UI_BLOCK_TIMEOUT = 3.5
local REAL_GIFT_ENTRY_PLIST = "ubfRes/ui/mod/SuperMagicBirdRealGift/SuperMagicBirdRealGift_Entrance.plist"
local REAL_GIFT_ENTRY_BIRD_SPINE = "ubfRes/ui/mod/SuperMagicBirdRealGift/spine/smoli_start.skel"
local REAL_GIFT_ADD_STEP_SPINE = "ubfRes/ui/mod/SuperMagicBirdRealGift/spine/SuperMagicBirdRealGift_AddStepDialog.skel"
local REAL_GIFT_REVIVE_CAROUSEL_ITEM = "revive_card"

local function getUiMgr()
    return UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER)
end

-- 尝试立即弹出交换引导
local function tryEnableSwapAdvice()
    if EnvUtil:isMiniGame() then return end
    local inst = UBFGameSceneManager:getInstance()
    if not inst then return end
    local modModule = inst:getGameModule(UBFGameLogics.kGameMod)
    if not modModule then return end

    local guideMgr = modModule:getModMgrBySourceId(UBFModSourceIdEnum.kGuide)
    if not guideMgr then return end
    
    local boardViewLogic = inst:getBoardViewLogic()
    local advice = boardViewLogic:getExtendLogic(UBFBoardViewExtendLogics.kMatchAdvice)
    if not advice then return end

    guideMgr:updateAdviceSwap()
    local swapList = advice:getLastSwapData()
    if not swapList or #swapList == 0 then return end

    local hasNice
    for _, v in ipairs(swapList) do
        local evaluate = v.evaluate or 0
        if evaluate >= 8 then hasNice = true break end
    end

    if not hasNice then return end
    guideMgr:rightNowShowSwapAdvice(true)
end

function SuperMagicBird2024:onGuideInit(event, ubfSLRuntime)
    local modMgr = ubfSLRuntime:getModMgr()
    local myData = modMgr:getModData(self.sourceId)
    if not myData then return end
    local myData = myData[1]
    local myData = myData and myData.env
    if not myData then return end
    local origin = event:getOrigin()

    if myData.birdThrowGroup and myData.birdThrowGroup > 1 and myData.hasSuperPower then 
        local levelJson = ubfSLRuntime:getLevelJsonData()
        local levelGroupInfo = ubfSLRuntime.levelGroupInfo
        if not levelGroupInfo then return end
        local hasGuide = UBFGuideConfigUtil:hasGuideInLevel(levelJson:getLevelUUID(), levelGroupInfo.meetGroup, ubfSLRuntime.levelScene)
        if not hasGuide then 
            table.insert(origin.extraGuides, "2747") 
        end
    end

    if not myData.bCanGuideProp then return end
    table.insert(origin.extraGuides, "2511") 
end

--检测mod是否要参与当前的流程(活动mod在注册时已经筛选过了)
function SuperMagicBird2024:isWillingEnabled(ubfSLRuntime, sourceId)
    if _G.UBF_AMF_ENABLED_FLAG and _G.editorMode then return true end
    return UBFGameActManager.isWillingEnabled(self, ubfSLRuntime, sourceId)
end

function SuperMagicBird2024:notifyEventStatic(event)
    UBFGameActManager.notifyEventStatic(self, event)

    local eventName = event:getEventName()
    local runtime = event:getRuntime()
    lua_switch(eventName) {
        [UBFGameModEventEnum.START] = function()
            self:_initSlData(runtime)
        end,
        -- [UBFGameModEventEnum.AFTER_PASS_LEVEL] = function()
        --     self:_initPlData(runtime)
        -- end,
    }
end

function SuperMagicBird2024:_getModContextData(runtime)
    local modMgr = runtime and runtime:getModMgr()
    local modContextData = (modMgr and modMgr:getModContextData(runtime.sourceId)) or {}
    return modContextData
end

-- 初始化startLevel流程相关数据
function SuperMagicBird2024:_initSlData(runtime)
    local modContextData = self:_getModContextData(runtime)

    local levelId = runtime:getLevelId()
    local levelScene = runtime:getLevelScene()

    local amfData = SmbAmfBridge.getSlData({
        levelId = levelId,
        levelScene = levelScene,
        isRetry = runtime:isRetry(),
        isAskForHelp = runtime:isAskForHelp(),
    })

    -- 关卡内框架是否启用
    modContextData.enabledInLevel = amfData.enabledInLevel
    -- 超鸟功能（关卡外）结束时间
    -- modContextData.actEndTime = amfData.actEndTime
    -- 超鸟当前是否在生效中
    modContextData.smbEffective = amfData.smbEffective
    -- 超鸟是否已激活
    modContextData.smbActivated = amfData.smbActivated
    -- 激活后连胜数
    modContextData.smbWinStreak = amfData.smbWinStreak
    -- 是否可展示前置魔力鸟上的超鸟tip
    modContextData.shouldShowPrePropIconTip = amfData.shouldShowPrePropIconTip
    -- 展示超鸟tip后给关卡外的回调（标记目前是关卡外在维护）
    modContextData.onShowPrePropIconTip = amfData.onShowPrePropIconTip
    -- 激活超鸟需要胜利的总局数
    modContextData.activationRequiredWins = amfData.activationRequiredWins
    -- 未激活状态下胜利数
    modContextData.activationCurrentWins = amfData.activationCurrentWins
    -- 检查关卡外资源是否加载完毕，加载完毕后再调用onLoaded（用于进行超鸟入口模块的真正入场）
    -- TODO 如果UI迁到关卡内，可以干掉
    modContextData.checkActivityResourceLoaded = amfData.checkActivityResourceLoaded
    -- 入口Icon是否有引导
    modContextData.hasEntryIconGuide = amfData.hasEntryIconGuide
    -- 弹出入口Icon引导
    modContextData.onPopEntryGuide = amfData.onPopEntryGuide
    -- 开始面板复活卡入口业务快照；取数失败时保留原有超鸟入口表现。
    if modContextData.enabledInLevel then
        modContextData.reviveCardSlpState = SmbAmfBridge.getReviveCardSlpState({
            levelId = levelId,
            levelScene = levelScene,
        })
    end
    local realGiftEntryState = SmbAmfBridge.getRealGiftEntryState()
    modContextData.realGiftEntryState = UBFHelper:deepClone(realGiftEntryState)
end

-- 初始化passLevel流程相关数据
-- function SuperMagicBird2024:_initPlData(runtime)
--     local modContextData = self:_getModContextData(runtime)

--     local amfData = SmbAmfBridge.getPlData({
--         levelId = runtime:getLevelId(),
--         levelScene = runtime:getLevelScene(),
--     })
-- end

function SuperMagicBird2024:setModSourceDataFromOutSide(ubfSLRuntime, modEnvData, levelId)
    local actMainManager = UBFActHelper:getActMainManager(ubfSLRuntime.sourceId)
    if not actMainManager or not actMainManager.getInLevelActData then
        return
    end
    local levelActData = actMainManager:getInLevelActData(levelId, ubfSLRuntime)
    UBFLogD(25, "SuperMagicBird2024:setModSourceDataFromOutSide, levelActData", levelActData)
    for i, v in pairs(levelActData or {}) do
        modEnvData[i] = v
    end
    local modContextData = self:_getModContextData(ubfSLRuntime)
    modEnvData.realGiftEntryState = UBFHelper:deepClone(modContextData.realGiftEntryState or {})
end

function SuperMagicBird2024:setFuuuAdjustData(runtime, modEnvData)
    local Meta = require "amf.feature.localactivity.supermagicbird.config.SuperMagicBirdConst"
    
    
    if modEnvData.fuuuType == Meta.fuuuTypeList.kNone then
        -- 不进行任何修正
    elseif modEnvData.fuuuType == Meta.fuuuTypeList.kV0 then
        local fuuuNum = modEnvData.oldFuuuNum
        if fuuuNum and modEnvData.bHistoryActiveBird then 
            fuuuNum = fuuuNum + 1

            if modEnvData.needBlockDiffFix then
                runtime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDiffFix(runtime.sourceId, modEnvData.blockDiffFixNum, UBFuuuFixMode.kSetVaule)
            else
                runtime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredDiffAvgBeforeBaodi(runtime.sourceId, fuuuNum, UBFuuuFixMode.kMultiplyVaule, { minValue = 1.03 })
            end
            
            if modEnvData.hasSuperPower then
                runtime.UBFuuuAdjustLogic:setSelfFeedbackPoolkey(runtime.sourceId, nil, _G.SelfFeedbackPoolkey.kSuperBird)
                runtime.UBFuuuAdjustLogic:setSelfFeedbackEnableFlag(runtime.sourceId, true)
            else
                runtime.UBFuuuAdjustLogic:setSelfFeedbackEnableFlag(runtime.sourceId, true)
            end
        end
    elseif modEnvData.fuuuType == Meta.fuuuTypeList.kV1 then
        local fuuuNum = modEnvData.newDiffcultyNum
        if fuuuNum then
            runtime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredDiffAvgBeforeBaodi(runtime.sourceId, fuuuNum, UBFuuuFixMode.kSetVaule, { minValue = 1.03 })
            runtime.UBFuuuAdjustLogic:setSelfFeedbackPoolkey(runtime.sourceId, _G.SelfFeedbackPoolkey.kSuperBird, _G.SelfFeedbackPoolkey.kSuperBird)
            runtime.UBFuuuAdjustLogic:setSelfFeedbackEnableFlag(runtime.sourceId, true)
        end
    elseif modEnvData.fuuuType == Meta.fuuuTypeList.kV2 then
        local fuuuNum = modEnvData.newStepNum
        if fuuuNum then 
            -- if modEnvData.v2mode == 1 then 
                runtime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredStep(runtime.sourceId, fuuuNum, UBFuuuFixMode.kSetVaule)
            -- else
            --     runtime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredStep(runtime.sourceId, fuuuNum)
            -- end
        end
    elseif modEnvData.fuuuType == Meta.fuuuTypeList.kV3 then
        local fuuuNum = modEnvData.oldFuuuNum
        if fuuuNum then 
            fuuuNum = fuuuNum + 1
            runtime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredDiffAvgBeforeBaodi(runtime.sourceId, "ubfuuu_bird_diff_map", UBFuuuFixMode.kMapping, { minValue = 1.03 })
            runtime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredDiffAvgBeforeBaodi(runtime.sourceId, fuuuNum, UBFuuuFixMode.kMultiplyVaule, { minValue = 1.03 })
            runtime.UBFuuuAdjustLogic:setSelfFeedbackPoolkey(runtime.sourceId, _G.SelfFeedbackPoolkey.kSuperBird, _G.SelfFeedbackPoolkey.kSuperBird)
            runtime.UBFuuuAdjustLogic:setSelfFeedbackEnableFlag(runtime.sourceId, true)
        end
    elseif modEnvData.fuuuType == Meta.fuuuTypeList.kV4 then
        local fuuuNum = modEnvData.oldFuuuNum
        if fuuuNum then 
            fuuuNum = fuuuNum + 1
            if modEnvData.needBlockDiffFix then
                runtime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDiffFix(runtime.sourceId, modEnvData.blockDiffFixNum, UBFuuuFixMode.kSetVaule)
            else
                runtime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredDiffAvgBeforeBaodi(runtime.sourceId, fuuuNum, UBFuuuFixMode.kMultiplyVaule, { minValue = 1.03 })
                runtime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredDiffAvgBeforeBaodi(runtime.sourceId, "ubfuuu_bird_diff_map", UBFuuuFixMode.kMapping, { minValue = 1.03 })
            end
            runtime.UBFuuuAdjustLogic:setSelfFeedbackPoolkey(runtime.sourceId, _G.SelfFeedbackPoolkey.kSuperBird, _G.SelfFeedbackPoolkey.kSuperBird)
            runtime.UBFuuuAdjustLogic:setSelfFeedbackEnableFlag(runtime.sourceId, true)
        end
    end

    if modEnvData.hasSuperPower then 
        local birdThrowGroup = modEnvData.birdThrowGroup
        if birdThrowGroup == 3
            or birdThrowGroup == 5
            or birdThrowGroup == 6
            or birdThrowGroup == 7
        then
            runtime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredDiffAvgBeforeBaodi(runtime.sourceId, "ubfuuu_super_magic_bird_charge_diff", UBFuuuFixMode.kMapping, { minValue = 1.03 })
        end
    end

    if (not EnvUtil:isMiniGame()) and (not EnvUtil:isAndroidPlatform(PlatformNameEnum.kHE)) and modEnvData.group and modEnvData.group == "G2" and modEnvData.hasSuperPower then
        runtime.UBFuuuAdjustLogic:replaceUBFuuuConfigFile(runtime.sourceId, UBFuuuConfigNameId.ubfuuu_diff_index_map, "ubfuuu_diff_index_map_superbird")
    end
end

function SuperMagicBird2024:createModResPrepare(ubfSLRuntime)
    local prepare = UBFResourceLoadManager:prepare()
    prepare:addPlist("tempFunctionResInLevel/SuperMagicBird2024/InLevel.plist") 
    if self:isUpdateVer1Available() then
        prepare:addPlist("ubfRes/ui/mod/SuperMagicBird/SuperMagicBird_SLP_Entry_Icon.plist")
        prepare:addSpine("ubfRes/ui/mod/SuperMagicBird/spine/smoli_tips.skel")
        prepare:addPlist(REAL_GIFT_ENTRY_PLIST)
        prepare:addSpine(REAL_GIFT_ENTRY_BIRD_SPINE)
        prepare:addSpine(REAL_GIFT_ADD_STEP_SPINE)
    end
    self.isForceNew = true
    return prepare
end

--获取仅视图记录的catch数据
function SuperMagicBird2024:customActViewData()
    self.actData.superCatchData = SmbAmfBridge.getLevelActCatchData()
    self.actData.foresume = true
    self.actData.adjustGroup = SmbAmfBridge.getAdjustGroup()
    self.actData.adjustGroupV2 = SmbAmfBridge.getAdjustGroupV2()
end

function SuperMagicBird2024:createCollectIconForAddStepPanel(iconConfig, forbidCreateView, forQuitPanel)
	local modEnvData = self:getModEnvData()
    
    local inst = UBFGameSceneManager:getInstance()
    if not inst then return end
    if not SmbAmfBridge.isEnabledInLevel(inst:getLevelInfo()) then return end
    if self:checkCurCanKeepWinRepeat() then return end

    local collectionId = iconConfig['iconName'] or self:getCollectionIdByIndex()
    local containCollectionId = iconConfig['containCollectionIds'] or collectionId
    local num = 0

	if collectionId == CollectionEnum.SUPER then 
		if not modEnvData.hasSuperPower then return false end
		-- if modEnvData.isLastGiftLevel then return false end
        -- elseif collectionId == CollectionEnum.GIFT then
        -- 	if not modEnvData.hasSuperPower then return false end
        -- 	if not modEnvData.isLastGiftLevel then return false end
        -- elseif collectionId == CollectionEnum.FLOWER then
        -- 	if modEnvData.hasSuperPower then return false end
        --     if modEnvData.hasTwoWinBuff then num = 2
        --     else num = 1 end
	else
		return false
	end

    local addFiveIcon
    if not forbidCreateView then addFiveIcon = self:createAddFiveIcon(iconConfig) end
    local iconRawData = self:getIconRawDataByCollectionId(collectionId, ActInLevelSceneType.kAddFivePanel)
    local addFiveIconUBFData
    if iconRawData then
        addFiveIconUBFData = {
            collectName = collectionId,
            ubfIconData = {
                rawData = iconRawData
            },
			-- numAsBottomText = true,
            -- topLabelText = self:getAddFiveStepIconCollectTag(iconConfig),
            tipReplaceText = self:getTouchAddFiveStepIconTipText(),
            numAsBottomText = self:getAddFiveBottomText(),
            forceText = {
                tip = self:getTouchAddFiveStepIconTipText(),
                bottomText = self:getAddFiveBottomText(),
            },
        }
    end
    return true, addFiveIcon, num, addFiveIconUBFData
end

function SuperMagicBird2024:getCollectionRate(collectionId)
    -- if collectionId == CollectionEnum.FLOWER then 
    --     local modEnvData = self:getModEnvData()
    --     if modEnvData.hasTwoWinBuff then return 2
    --     else return 1 end
    -- end
    return UBFGameActManager.getCollectionRate(self, collectionId)
end

function SuperMagicBird2024:getAddFiveStepIconCollectTag()
    return nil
end

function SuperMagicBird2024:getAddStepMultipleRate(collectionId)
    -- if collectionId == CollectionEnum.FLOWER then 
    --     local modEnvData = self:getModEnvData()
    --     if modEnvData.hasTwoWinBuff then return 1
    --     else return 0 end
    -- end
    return 0
end

function SuperMagicBird2024:addDecorateToIcon(scene, icon, collectionId)
    local curTotalRate = self:getAddStepMultipleRate(collectionId) + 1
    if scene ~= ActInLevelSceneType.kPassLevelPanel and curTotalRate > 1 then
        local bonusImage = self:createBonusView(curTotalRate .. "倍", 1.75)
        icon:addChild(bonusImage)
        bonusImage:setPositionXY(65, 110)
    end
end

function SuperMagicBird2024:cancelPush(runtime)
    if EnvUtil then
        local LocalPush = require "amf.feature.localactivity.supermagicbird.localpush.LocalPush"
        LocalPush:removeLocalPush()
        return
    end
    local actId = self.sourceId or ( runtime and runtime.sourceId )
	NotifycationBridge:cancelActivityNoti2(tonumber(actId))
end

function SuperMagicBird2024:tryRegisterPush(runtime)
    if EnvUtil then
        local LocalPush = require "amf.feature.localactivity.supermagicbird.localpush.LocalPush"
        LocalPush:checkLocalPush()
        return
    end
	self:cancelPush()
	local pushList = {}
	local curTime = TimeKit:timeInSec()
    local config = {
        [1] = { time = curTime + 1*3600, text = "检测到您上一关还未结束，请尽快回归，保住超级魔力鸟！" },
        [2] = { time = curTime + 24*3600, text = "检测到您上一关意外退出游戏，请尽快回归，保住超级魔力鸟！" }
    }

    for i, v in ipairs(config) do
        local singlePush = {
			time = v.time,
			title = "超级魔力鸟提醒",
			content = v.text,
			typeId = LocalNotificationType.kActivity2,
		}
		table.insert(pushList, singlePush)
    end

	if #pushList > 0 then
        local actId = self.sourceId or ( runtime and runtime.sourceId )
		NotifycationBridge:setActivityNoti2ByList(pushList, tonumber(actId))
	end
end

function SuperMagicBird2024:createAdditionalBuffBuilder(modList, runtime, modEnvData) --todo create开头的方法，应该返回构造结果，而不是篡改参数对象内部
    if not modEnvData then return end
    if not modEnvData.hasSuperPower then return end
    local builder = UBFPlayImproveBuffBuilder:create()
    builder:setModSourceId(runtime.sourceId)
    builder:addBuffItemType(UBFGameItemType.kBuffSuperMagicBird)
    table.insert(modList, builder:toBuffCreateData())
    self:tryRegisterPush(runtime)
end

function SuperMagicBird2024:onGuideMaskDisappear(event)
    local eventData = event:getOrigin()
    local guideData = eventData and eventData.guideData or nil
    if not guideData then return end
    local guideFlag = guideData.guideFlag
    local modEnvData = self:getModEnvData()
    if tostring(guideFlag) == "2511" then 
        local superCatchData = self.actData.superCatchData
        if superCatchData then superCatchData.hadGuideProp = true end
        setNextFrame(tryEnableSwapAdvice) 
    end
end

function SuperMagicBird2024:onUBFAddFivePanelCheckNPCDialog(event)
    local modEnvData = self:getModEnvData()
    if not modEnvData or not modEnvData.hasSuperPower then return false end
    -- if not UBFAddStepSuperMBUtil:isAddFiveEntryAvailable(modEnvData) then return end

    local eventData = event:getOrigin()
    local panelContext = eventData.panelContextData
	if not panelContext then return end
    eventData["hasSuperMagicBirdNPCPop"] = true
    if panelContext.secondEntryID then
        if not eventData["dialogBuildData"] then eventData["dialogBuildData"] = {} end
        local realGiftState = modEnvData.realGiftEntryState or {}
        local useRealGiftDialog = realGiftState.enabled == true
        eventData["dialogBuildData"]["2"] = self:_getNPCDialogBuildData(useRealGiftDialog)
    end
    event:setBlock()
end

function SuperMagicBird2024:_getNPCDialogBuildData(useRealGiftDialog)
    local modEnvData = self:getModEnvData()

    local dialogBuildData = {}
	dialogBuildData["customBuildFunc"] = function (...) 
        if useRealGiftDialog then
            return SuperMagicBird2024:_customRealGiftDialogBuildFunc(...)
        end
        local winStreakNum = (modEnvData and modEnvData.currWinStreakNum) or 1
        if winStreakNum <= 4 then
            return SuperMagicBird2024:_customVer1StaticDialogBuildFunc(...)
        else
            return SuperMagicBird2024:_customVer1AnimationDialogBuildFunc(...)
        end
    end
    dialogBuildData.isLastGiftLevel = modEnvData.isLastGiftLevel
    dialogBuildData["hideInSecondConfirm"] = true
	return dialogBuildData
end

--[[
function SuperMagicBird2024:_customBuildFunc(data)

    local layer = Layer:create()

    -- local panel = require "ubf.UBFActivity.actFolder.SuperMagicBird2024.ui.supermb_add_step_tip_UI"
	-- local p = panel:create()
    -- layer:addChild(p)
    -- p:setPositionXY(-40, 165)
    -- p:setScale(1.1)

    -- if p.inner_label_reward_1 then 
    --     local str = '放弃本关，将失去\n'
    --     p.inner_label_reward_1:setString(str)
    -- end
    -- local textLabel = p.ui:getChildByName("inner"):getChildByName("text")
    -- textLabel:setString("超级魔力鸟")
    -- local labelSize = textLabel:getGroupBounds().size
    -- local label2 = p.ui:getChildByName("inner"):getChildByName("label2")
    -- label2:setPositionX(textLabel:getPositionX() + labelSize.width - 10)
    -- if data.isLastGiftLevel then label2:setString("大奖")
    -- else label2:setString("助力") end

    -- local icon = p.ui:getChildByName("inner"):getChildByName("inner_label_reward_2")
    -- icon:setVisible(false)

    -- local replaceIcon = nil
    -- -- if data.isLastGiftLevel then 
    -- --     replaceIcon = UIHelper:createSpriteWithPlist("tempFunctionResInLevel/SuperMagicBird2024/InLevel.plist" , "superMagicBird2024_gift_icon" )
    -- -- else
    --     replaceIcon = UIHelper:createSpriteWithPlist("tempFunctionResInLevel/SuperMagicBird2024/InLevel.plist" , "superMagicBird2024_bird_icon" )
    -- -- end
    
    -- replaceIcon:setAnchorPoint(ccp(0, 1))
    -- replaceIcon:setScale(0.8)

    -- local myIndex = p.ui:getChildByName("inner"):getChildIndex(icon)
    -- p.ui:getChildByName("inner"):addChildAt(replaceIcon, myIndex)
    -- replaceIcon:setPositionXY( icon:getPositionX(), icon:getPositionY() )

    -- local cha = p.ui:getChildByName("inner"):getChildByName("ui_com_cha")
    -- UIHelper:changeAnchorButView(cha,ccp(0.5, 0.5))
    -- local CommonAnimCreateUtils = require_debug("ubf.old.UIKit.utils.CommonAnimCreateUtils.lua")
    -- CommonAnimCreateUtils:playShakeAnim(cha)

    UBFRawViewAsyncCreator:createView({
        type = UBFRawViewCreator.ViewType.kUI,
        lua = "ubf.UBFActivity.actFolder.SuperMagicBird2024.ui.supermb_add_step_tip_UI",
    }):next(function(view)
        if not view then return end
        if layer.isDisposed then return view:removeFromParentAndCleanup() end
        -- 空格比例不一样，传说是6 = 5
        if view.fields and EnvUtil:isUnity() then
            local babel = view.fields.label_level
            if babel then babel:setString("放弃本关, 将失去\n                   助力") end
        end
        UBFRawViewAsyncCreator:createView({
            type = UBFRawViewCreator.ViewType.kImage,
            plist = "tempFunctionResInLevel/SuperMagicBird2024/InLevel.plist",
            frameName = "superMagicBird2024_bird_icon",
        }):next(function(replaceIcon)
            if not replaceIcon then return view:removeFromParentAndCleanup() end
            local icon = view.fields.icon
            icon:addChild(replaceIcon)
            replaceIcon:setAnchorPoint(ccp(0, 0))
            replaceIcon:setScale(0.8)
            view:setPositionXY(-20, 155)
            if layer.isDisposed then return view:removeFromParentAndCleanup() end
            layer:addChild(view)
        end)
    end)

    return layer
end
--]]

function SuperMagicBird2024:_customVer1StaticDialogBuildFunc(data)
    local layer = Layer:create()

    UBFRawViewAsyncCreator:createView({
        type = UBFRawViewCreator.ViewType.kUI,
        lua = "ubf.UBFActivity.actFolder.SuperMagicBird2024.ui.SuperMagicBird_ASP_dialog_UI",
    }):next(function(view)
        if not view then return end
        if layer.isDisposed then return view:removeFromParentAndCleanup() end

        view:setPositionXY(30, 0)
        layer:addChild(view)
    end)

    return layer
end

function SuperMagicBird2024:_customVer1AnimationDialogBuildFunc(data)
    local layer = Layer:create()

    UBFRawViewAsyncCreator:createView({
        type = UBFRawViewAsyncCreator.ViewType.kSpine,
		skel = "ubfRes/ui/mod/SuperMagicBird/spine/smoli_tips.skel",
	}):next(function (animNode)
        if not animNode then return end
        if layer.isDisposed then return animNode:removeFromParentAndCleanup() end

		animNode:setPosition(ccp(80, -20))
		layer:addChild(animNode)

        UBFViewHelper:makeAdvancedSpine(animNode)
        animNode:playSequence(true, nil, "in", "idle")
	end)

    return layer
end

function SuperMagicBird2024:_customRealGiftDialogBuildFunc(data)
    local layer = Layer:create()

    UBFRawViewAsyncCreator:createView({
        type = UBFRawViewAsyncCreator.ViewType.kSpine,
        skel = REAL_GIFT_ADD_STEP_SPINE,
    }):next(function(animNode)
        if not animNode then return end
        if layer.isDisposed then return animNode:removeFromParentAndCleanup() end

        animNode:setPosition(ccp(80, -20))
        layer:addChild(animNode)
        UBFViewHelper:makeAdvancedSpine(animNode)
        animNode:playSequence(true, nil, "in", "idle")
    end)

    return layer
end

function SuperMagicBird2024:getStageDcDataForActInfo(category, levelContext)
    UBFGameActManager.getStageDcDataForActInfo(self, category, levelContext)
    if category == "stage_quit" or category == "stage_end" then
        if not self.actMainManager then return end

        local levelInfo, modEnvData = self:getActInLevelData()
        local superCatchData = self.actData.superCatchData
        if not superCatchData then return nil end
        if not superCatchData.pworth then superCatchData.pworth = {} end
        local actDcData = SmbAmfBridge.getEndLevelDcData(superCatchData, modEnvData)
        if not actDcData or UBFHelper:isTableEmpty(actDcData) then return nil end
        return actDcData
    elseif category == "stage_start" then
        local levelInfo, modEnvData = self:getActInLevelData()
        return { magicbrid = modEnvData.hasSuperPower and 1 or 0 }
    end
	return nil
end

function SuperMagicBird2024:updateActPassLevelData(passLevelData)
    self:cancelPush()
    local superCatchData = self.actData.superCatchData
    if superCatchData then 
        local inst = UBFGameSceneManager:getInstance() or UBFPrevSceneManager:getInstance()
        if inst then 
            local UBFEndLevelData = require 'ubf.UBFPlay.data.UBFEndLevelData'
            local endLevelData = UBFEndLevelData.new()
            endLevelData:fromLua(inst:getEndLevelData() or {})
            local ubfuuu = endLevelData:getUBFuuuDcData()
            if ubfuuu then superCatchData.diffFix = ubfuuu.diffFix end
            local sceneData = inst:getSceneData()
            superCatchData.pworth = sceneData.pworth or {}
        end
    end
    if not superCatchData.pworth then superCatchData.pworth = {} end
    UBFGameActManager.updateActPassLevelData(self, passLevelData)
    if passLevelData.passLevelJson then 
        local modEnvData = self:getModEnvData()
        passLevelData.passLevelJson.hasSuperPower = modEnvData.hasSuperPower
        -- if modEnvData.hasTwoWinBuff then 
        --     passLevelData.passLevelJson.dp = true
        -- else
        --     passLevelData.passLevelJson.dp = false
        -- end
    end
end

function SuperMagicBird2024:getAddFiveBottomText()
    local modEnvData = self:getModEnvData()
    if UBFLevelSceneFunc:isFullLevelLib(modEnvData.levelScene) then 
        return "连胜保持"
    elseif modEnvData.levelSupportType == LevelSupportModeType.kExceedStar then
        return "补彩星保持"
    else 
        return "连胜保持"
    end
end

function SuperMagicBird2024:getTouchAddFiveStepIconTipText()
    local modEnvData = self:getModEnvData()
    if UBFLevelSceneFunc:isFullLevelLib(modEnvData.levelScene) then 
        return "连胜保持超级魔力鸟"
    elseif modEnvData.levelSupportType == LevelSupportModeType.kExceedStar then
        return "连续补彩星成功保持超级魔力鸟"
    else 
        return "连胜保持超级魔力鸟"
    end
end

local function getSuperMagicBirdPrePropData(initTipParams)
    return {
        superMagicBirdActive = true,
        initTipParams = initTipParams,
        extraViews = {
            propIconContent = {
                viewType = UBFUiViewType.SPRITE,
                plist = "tempFunctionResInLevel/SuperMagicBird2024/InLevel.plist",
                frameName = "superMagicBird2024_bird_icon",
                scale = 0.754,
                parentViewName = "propIcon",
            },
        },
        buyPropCreateData = {
            propIcon = {
                viewType = UBFUiViewType.SPRITE,
                plist = "tempFunctionResInLevel/SuperMagicBird2024/InLevel.plist",
                frameName = "superMagicBird2024_bird_icon",
            },
            desc = {
                rawData = {
                    type = UBFRawViewCreator.ViewType.kText,
                    kind = "MultiLabel",
                    multiLabelData = {
                        width = 600,
                        messageList = {
                            {
                                text = "关卡开始时出现一个",
                                color = hex2ccc4("B2714AFF"),
                                fontSize = 24,
                            },
                            {
                                text = "超级魔力鸟",
                                color = hex2ccc4("E96B33FF"),
                                fontSize = 24,
                            },
                            {
                                text = "，当局有效",
                                color = hex2ccc4("B2714AFF"),
                                fontSize = 24,
                            },
                        },
                    },
                },
            },
        },
    }
end

-------------------------------开始面板篡改-------------------------------
function SuperMagicBird2024:_refreshSlpEntry(entryContext, refreshReason, segment)
    return getUiMgr():exeOp(UBFSuperMB2024OpType.SLP_REFRESH_ENTRY, {
        nodeId = entryContext.nodeId,
        nodeGid = entryContext.nodeGid,
        levelId = entryContext.levelId,
        levelScene = entryContext.levelScene,
        entryData = entryContext.entryData,
        refreshReason = refreshReason,
    }, segment)
end

function SuperMagicBird2024:_refreshSlpPreProp(session, segment)
    local prePropGroupNodeGid = session.prePropGroupNodeGid
    if not prePropGroupNodeGid then return end

    local uiMgr = getUiMgr()
    local prePropNodeGid = uiMgr:findNodeGid({
        nodeId = UBFSlpNodeId.PRE_PROP_ITEM,
        parentNodeGid = prePropGroupNodeGid,
        propInfo = {
            srcPropId = UPropId.PRE_RANDOM_BIRD,
        },
    })
    if not prePropNodeGid or not uiMgr:isNodeReady(prePropNodeGid) then return end

    return uiMgr:exeOp(UBFUiOpType.UPDATE_UI, {
        nodeGid = prePropNodeGid,
        uiData = {
            nodeConfig = {
                data = {
                    [prePropNodeGid] = getSuperMagicBirdPrePropData(),
                },
            },
        },
    }, segment)
end

function SuperMagicBird2024:_dispatchSlpRefreshAnimFinished(mainNodeGid)
    local uiMgr = getUiMgr()
    if not uiMgr or not mainNodeGid then
        return
    end
    uiMgr:dispatchUiEvent(UBFSuperMB2024UiEventType.SLP_REFRESH_ANIM_FINISHED, {
        eventType = UBFSuperMB2024UiEventType.SLP_REFRESH_ANIM_FINISHED,
        nodeGid = mainNodeGid,
    })
end

function SuperMagicBird2024:_refreshSlpActivationUi(session, entryContext)
    local refreshSegment = UBFPromise:segment()
    self:_refreshSlpEntry(entryContext, "activation_checked", refreshSegment)
    self:_refreshSlpPreProp(session, refreshSegment)
    refreshSegment:next(function()
        self:_dispatchSlpRefreshAnimFinished(session and session.mainNodeGid)
    end)
    refreshSegment:resolve()
    return refreshSegment
end

function SuperMagicBird2024:_runSlpActivationPresentation(session, entryContext)
    local presentationPromise = UBFPromise:create()
    session.activationResultPromise:next(function(activationSucceeded)
        local uiMgr = getUiMgr()
        local function isPresentationContextReady()
            return uiMgr:isNodeReady(session.mainNodeGid)
                and uiMgr:isNodeReady(entryContext.nodeGid)
        end

        if activationSucceeded and isPresentationContextReady() then
            SmbAmfBridge.popAnimV2(function()
                self:_refreshSlpActivationUi(session, entryContext):next(function()
                    presentationPromise:resolve()
                end)
            end, {
                canPresent = isPresentationContextReady,
                prePopoutDelay = 0,
                skipPostFlyDelay = true,
                flyTargetWorldPositionGetter = function()
                    if not isPresentationContextReady() then return end
                    return uiMgr:callNode(entryContext.nodeGid, "getIconWorldPosition")
                end,
                reopenStartPanel = false,
            })
            return
        end
        presentationPromise:resolve()
    end)
    return presentationPromise
end

function SuperMagicBird2024:_tryGetReviveCardRewardOnSlp(entryContext)
    local rewardPromise = UBFPromise:create()
    local function finishRequest()
        rewardPromise:resolve()
    end
    local function onSuccess()
        local refreshPromise = self:_refreshSlpEntry(entryContext, "rewarded")
        if refreshPromise then
            refreshPromise:next(finishRequest)
        else
            finishRequest()
        end
    end

    local didRequest = SmbAmfBridge.tryGetReviveCardReward(onSuccess, finishRequest, finishRequest)
    if not didRequest then
        finishRequest()
    end
    return rewardPromise
end

function SuperMagicBird2024:_unblockUiDuringActivation(session)
    if not session.isUiBlocked then return end
    session.isUiBlocked = false
    if session.uiBlockTimerId then
        cancelTimeOut(session.uiBlockTimerId)
        session.uiBlockTimerId = nil
    end

    getUiMgr():callNodeIfExists(session.rootNodeGid, "unblockUi", {
        unblockRoot = false,
    })
end

function SuperMagicBird2024:_blockUiDuringActivation(session)
    local uiMgr = getUiMgr()
    if not uiMgr:isNodeViewSafe(session.rootNodeGid) then return end

    uiMgr:callNode(session.rootNodeGid, "blockUi", {
        blockRoot = false,
        blockFeedback = false,
    })
    session.isUiBlocked = true
    session.uiBlockTimerId = setTimeOut(function()
        session.uiBlockTimerId = nil
        self:_unblockUiDuringActivation(session)
    end, SLP_ACTIVATION_UI_BLOCK_TIMEOUT)
end

function SuperMagicBird2024:_requestActivateOnSlp(session)
    local activationResultPromise = session.activationResultPromise
    self:_blockUiDuringActivation(session)

    local function finishRequest(activationSucceeded)
        self:_unblockUiDuringActivation(session)
        activationResultPromise:resolve(activationSucceeded)
    end
    local function onFail()
        finishRequest(false)
    end

    SmbAmfBridge.requestActivate(function()
        finishRequest(SmbAmfBridge.isActivated())
    end, onFail, onFail)
    return activationResultPromise
end

function SuperMagicBird2024:onPrepareSlpEnterActions(event)
    local runtime = event:getRuntime()
    self:cancelPush(runtime)

    local eventData = event:getOrigin()
    if not eventData then return end

    local modContextData = self:_getModContextData(runtime)
    local currentProgress = tonumber(modContextData.activationCurrentWins) or 0
    local requiredWins = tonumber(modContextData.activationRequiredWins) or math.huge
    local shouldRequestActivate = self:isUpdateVer1Available()
        and not runtime:isRetry()
        and modContextData.enabledInLevel
        and not modContextData.smbActivated
        and currentProgress >= requiredWins

    local uiMgr = getUiMgr()
    local delegate = eventData.createDelegate
    local entryNodeGid = delegate and delegate:getNodeGid(UBFSuperMB2024NodeId.SLP_RIGHT_UPPER)
    local prePropGroupNodeGid = delegate and delegate:getNodeGid(UBFSlpNodeId.PRE_PROP_GROUP)
    local session
    if shouldRequestActivate and entryNodeGid and eventData.nodeGid and eventData.mainNodeGid then
        session = {
            rootNodeGid = eventData.nodeGid,
            mainNodeGid = eventData.mainNodeGid,
            prePropGroupNodeGid = prePropGroupNodeGid,
            activationResultPromise = UBFPromise:create(),
        }
        uiMgr:registerTrigger({
            tag = "SuperMagicBird2024_ActivateFallback",
            triggerPoint = {
                eventType = UBFUiEventType.NODE_ENTER_TRANSITION_END,
                nodeId = UBFSlpNodeId.MAIN,
                nodeGid = eventData.mainNodeGid,
            },
            action = {
                type = UBFUiActionType.FUNCTION,
                func = function()
                    return self:_requestActivateOnSlp(session)
                end,
            },
        })
    end

    if entryNodeGid then
        local triggerPoint = {
            eventType = UBFSuperMB2024UiEventType.SLP_ENTRY_PRESENTATION_FINISHED,
            nodeId = UBFSuperMB2024NodeId.SLP_RIGHT_UPPER,
            nodeGid = entryNodeGid,
        }
        if session then
            uiMgr:registerTrigger({
                tag = "SuperMagicBird2024_ActivationPresentation",
                triggerPoint = triggerPoint,
                action = {
                    type = UBFUiActionType.FUNCTION,
                    func = function(context)
                        return self:_runSlpActivationPresentation(session, context)
                    end,
                },
            })
        end

        -- 首次入口创建时关卡外活动数据可能仍在同步；展示完成后重新读取一次，
        -- 确保抽奖机会 tip 不会因为初始快照过早而延迟到下一次打开才出现。
        uiMgr:registerTrigger({
            tag = "SuperMagicBird2024_EntryTipRefresh",
            triggerPoint = triggerPoint,
            action = {
                type = UBFUiActionType.FUNCTION,
                func = function(context)
                    local entryData = context.entryData or {}
                    if entryData.state ~= UBFSuperMB2024SlpEntryState.ACTIVATED then
                        return
                    end
                    return self:_refreshSlpEntry({
                        nodeId = context.nodeId,
                        nodeGid = context.nodeGid,
                        levelId = context.levelId,
                        levelScene = context.levelScene,
                        entryData = entryData,
                    }, "presentation_finished")
                end,
            },
        })

        uiMgr:registerTrigger({
            tag = "SuperMagicBird2024_ReviveCardReward",
            triggerPoint = triggerPoint,
            action = {
                type = UBFUiActionType.FUNCTION,
                func = function(context)
                    return self:_tryGetReviveCardRewardOnSlp(context)
                end,
            },
        })
    end

    -- if runtime:isRetry() and not self:checkCurCanKeepWinRepeat() then return end

    -- local modContextData = self:_getModContextData(runtime)
    -- if not modContextData.smbEffective then return end

    -- local actEndTime = modContextData.actEndTime
    -- if not actEndTime then return end

    -- local uiMgr = UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER)
    -- local mainNodeGid = event:getOrigin().mainNodeGid
    -- uiMgr:registerTrigger({
    --     tag = "SuperMagicBird2024_CountdownTimer",
	-- 	triggerPoint = {
	-- 		eventType = UBFUiEventType.NODE_ENTER_TRANSITION_END,
	-- 		nodeId = UBFSlpNodeId.MAIN,
    --         nodeGid = mainNodeGid,
	-- 	},
	-- 	runCondition = {
	-- 		-- node如果开始退场，则自动跳过
	-- 		beforeNodeExit = true,
	-- 	},
	-- 	action = {
	-- 		type = UBFUiActionType.FUNCTION,
	-- 		-- return值必须为一个promise，在resolve时会执行队列里下一个任务
	-- 		func = function(context)
	-- 			local promise = UBFPromise:create()
    --             self.superMagicBirdTimer = CCDirector:sharedDirector():getScheduler():scheduleScriptFunc(function()
    --                 if not uiMgr:existNode(mainNodeGid) or uiMgr:callNode(mainNodeGid, "isExitStarted") then
    --                     self:_unscheduleSuperMagicBirdTimer()
    --                     return
    --                 end
    --                 local countDownTime = actEndTime - Localhost:timeInSec()
    --                 if countDownTime <= 0 then
    --                     self:resetSuperMagicBirdIcon()
    --                     self:_unscheduleSuperMagicBirdTimer()
    --                     return
    --                 end
    --             end, 1)
    --             promise:resolve()
	-- 			return promise
	-- 		end,
	-- 	},
	-- })

end

-- function SuperMagicBird2024:_unscheduleSuperMagicBirdTimer()
--     if self.superMagicBirdTimer then
--         CCDirector:sharedDirector():getScheduler():unscheduleScriptEntry(self.superMagicBirdTimer)
--         self.superMagicBirdTimer = nil
--     end
-- end

function SuperMagicBird2024:onPrepareSlp(event)
    local eventData = event:getOrigin()
    local delegate = eventData.slpCreateDelegate
    if not delegate then return end

    if EnvUtil:isDevelopMode() then
        delegate.nodeConfig:insert(UBFSlpNodeId.DEBUG_WIDGET, "itemsData", 
            {
                text = "超鸟调试",
                onClick = function()
                    local AIMoreMoreMod = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.AI.AIMoreMoreMod"
                    function AIMoreMoreMod:isWillingEnabled(runtime, sourceId)
                        if not (runtime:isAIMode() or _G._dev_more_more_easy_buff_) then return false end
                        return runtime:getProcessType() == UBFProcessTypeEnum.START_LEVEL
                    end
                    local is_start = _G._dev_more_more_easy_buff_
                    if not is_start then
                        CommonTip:showTip("超鸟已启动")
                        _G._dev_more_more_easy_buff_ = function(prepropThrowBuilder, prepropImproveBuilder)
                            prepropImproveBuilder:addBuffItemType(UBFGameItemType.kBuffSuperMagicBird)
                            SuperMagicBird2024:tryRegisterPush(event:getRuntime())
                        end
                    else
                        CommonTip:showTip("超鸟已关闭")
                       _G._dev_more_more_easy_buff_ = nil
                    end
                    local process = UBFProcessManager:getCurrStartProcess()
                    if process then process:abort() end
                    if _G.dev_i_can_easy_replay_level_nice_func then
                        setNextFrame(_G.dev_i_can_easy_replay_level_nice_func)
                    end
                end,
            }
        )

        delegate.nodeConfig:insert(UBFSlpNodeId.DEBUG_WIDGET, "itemsData", {
            text = "禁超鸟强弹",
            collapseOnClick = true,
            onClick = function()
                local amfMgr = _G.amfBean("SuperMagicBird2024Manager")
                if amfMgr._slpDebugOriginalTryActivatePop ~= nil then
                    amfMgr.tryActivatePop = amfMgr._slpDebugOriginalTryActivatePop
                    amfMgr._slpDebugOriginalTryActivatePop = nil
                    CommonTip:showTip("已启用超鸟强弹")
                else
                    amfMgr._slpDebugOriginalTryActivatePop = amfMgr.tryActivatePop
                    amfMgr.tryActivatePop = function(_, onHandleOver)
                        safeRunCall(onHandleOver)
                    end
                    CommonTip:showTip("已禁止超鸟强弹")
                end
            end,
        })
    end

    local runtime = event:getRuntime()
    if runtime:isRetry() and not self:checkCurCanKeepWinRepeat() then return end
    local modContextData = self:_getModContextData(runtime)
    if not modContextData.smbEffective then return end

    local prePropData = getSuperMagicBirdPrePropData()
    if modContextData.shouldShowPrePropIconTip then
        prePropData.initTipParams = {title = "超级魔力鸟生效中", disappearSec = 1.5}
        safeRunCall(modContextData.onShowPrePropIconTip)
    end
    delegate.nodeConfig:merge(UBFSlpNodeId.PRE_PROP_GROUP, "itemsCreateData", {
        [UPropId.PRE_RANDOM_BIRD] = prePropData,
    })
end

function SuperMagicBird2024:resetSuperMagicBirdIcon()
    local uiMgr = getUiMgr()
    local updateData = {
        superMagicBirdActive = NIL,
        extraViews = {
            propIconContent = NIL,
        },
        buyPropCreateData = {
            propIcon = NIL,
            desc = NIL,
        }
    }
    uiMgr:callNode({
        nodeId = UBFSlpNodeId.PRE_PROP_ITEM,
        propInfo = {
            srcPropId = UPropId.PRE_RANDOM_BIRD,
        }
    }, "update", updateData)
end

function SuperMagicBird2024:checkCurCanKeepWinRepeat()
    local inst = UBFGameSceneManager:getInstance()
    if not inst then return end
    local levelInfo = inst:getLevelInfo()
    local sceneData = inst:getSceneData()
    local tallyUnit = inst:callGameModule(UBFGameLogics.kTally, "getTallyUnit", UBFTallyId.kMoveStep)
    local moveCount = tallyUnit and tallyUnit:getValue(UBFTallyValueType.kMoveCount) or 0
    local staticMove = levelInfo.staticMove
    if SmbAmfBridge.isEnabledInLevel(levelInfo) then
        return SmbAmfBridge.checkCurCanKeepWinRepeat(moveCount, staticMove)
    else
        return false
    end
end

--
--
--
--

function SuperMagicBird2024:isUpdateVer1Available()
    local MaintenanceName = "superbird_app"
    if EnvUtil:isMiniGame() then
        MaintenanceName = "superbird_mini"
    end
    local isValid = MaintenanceManager:getInstance():isEnabledInGroup(MaintenanceName, "ON")
    if isValid then
        return true
    end
    return false
end

------------------------------------------- 开始面板入口Icon -------------------------------------------------
function SuperMagicBird2024:onViewStaticInit()
	require "ubf.UBFActivity.actFolder.SuperMagicBird2024.SuperMagicBird2024ModDeclares"
    require "ubf.UBFActivity.actFolder.SuperMagicBird2024.UBFSlpRightUpperSuperMBEntry"

    local uiMgr = getUiMgr()

    local function isEntryViewSafe(nodeGid)
        return nodeGid and uiMgr:isNodeViewSafe(nodeGid)
    end

    local function updateSlpEntryNode(nodeGid, nodeData)
        if not isEntryViewSafe(nodeGid) then
            return UBFPromise:create():resolve()
        end
        return uiMgr:exeOp(UBFUiOpType.UPDATE_UI, {
            nodeGid = nodeGid,
            uiData = {
                nodeConfig = {
                    data = {
                        [nodeGid] = {
                            slpRightUpperData = nodeData,
                        },
                    },
                },
            },
        })
    end

    local function closeSlp(opParams)
        uiMgr:exeOp(UBFSlpOpType.CLOSE, {
            nodeId = opParams.nodeId,
            nodeGid = opParams.nodeGid,
            resetPopup = true,
        })
    end

    local function jumpToActPanel(opParams)
        local entryData = opParams.entryData or {}
        local clickedReviveCard = entryData.state == UBFSuperMB2024SlpEntryState.REVIVE_CARD_AVAILABLE
            and (entryData.carouselItem == nil or entryData.carouselItem == REAL_GIFT_REVIVE_CAROUSEL_ITEM)
        -- 复活卡确认面板曝光的来源：false=开始面板，true=重试面板（关卡外据此区分打点来源）
        local isRetryPanel = opParams.isRetryAfterFail == true
        local shouldOpenReviveDirectly = isRetryPanel
            or SmbAmfBridge.isReviveCardSlpMockEnabled()
        if clickedReviveCard and shouldOpenReviveDirectly then
            SmbAmfBridge.openReviveConfirmPanel({
                isRetryPanel = isRetryPanel,
                closeCallback = function(activateSucceeded)
                    if activateSucceeded then
                        local updateData = getSuperMagicBirdPrePropData()
                        updateData.extraViews.propIconContent.updateType = UBFUiUpdateType.CREATE
                        updateData.extraViews.propIconContent.replaceViewName = "propIconContent"
                        uiMgr:callNode({
                            nodeId = UBFSlpNodeId.PRE_PROP_ITEM,
                            propInfo = {
                                srcPropId = UPropId.PRE_RANDOM_BIRD,
                            }
                        }, "update", updateData)
                    end
                    if not isEntryViewSafe(opParams.nodeGid) then return end
                    local refreshSegment = uiMgr:exeOp(UBFSuperMB2024OpType.SLP_REFRESH_ENTRY, {
                        nodeId = opParams.nodeId,
                        nodeGid = opParams.nodeGid,
                        levelId = opParams.levelId,
                        levelScene = opParams.levelScene,
                        entryData = opParams.entryData,
                        refreshReason = "activate_panel_closed",
                    })
                    if refreshSegment then
                        refreshSegment:next(function ()
                            local mainNodeGid = activateSucceeded and uiMgr:getLastNodeGid(UBFSlpNodeId.MAIN)
                            if mainNodeGid then
                                self:_dispatchSlpRefreshAnimFinished(mainNodeGid)
                            end
                        end)
                    end
                end,
            })
            return
        end

        local extra = {
            levelId = opParams.levelId,
            levelScene = opParams.levelScene,
            isRetryPanel = isRetryPanel,
            closeSlpCallback = function()
                closeSlp(opParams)
            end,
            clickedReviveCard = clickedReviveCard
        }

        if not SmbAmfBridge.tryOpenRealGiftActPanel(nil, extra) then
            SmbAmfBridge.openActPanel(nil, extra)
        end

    end

    -- 跳转活动面板
    uiMgr:registerOp(UBFSuperMB2024OpType.SLP_JUMP_TO_ACT_PANEL, function(opParams)
        jumpToActPanel(opParams)
    end)

    -- 重新读取关卡外真实状态并定点刷新当前入口。
    uiMgr:registerOp(UBFSuperMB2024OpType.SLP_REFRESH_ENTRY, function(opParams)
        local nodeGid = opParams.nodeGid
        if not isEntryViewSafe(nodeGid) then
            return UBFPromise:create():resolve()
        end

        local reviveCardState = SmbAmfBridge.getReviveCardSlpState({
            levelId = opParams.levelId,
            levelScene = opParams.levelScene,
        })
        local realGiftEntryState = SmbAmfBridge.getRealGiftEntryState()
        if not isEntryViewSafe(nodeGid) then
            return UBFPromise:create():resolve()
        end

        local nodeData = self:_getRefreshedSlpEntryIconData(
            reviveCardState,
            opParams.entryData,
            opParams.refreshReason,
            realGiftEntryState
        )
        return updateSlpEntryNode(nodeGid, nodeData)
    end, true)
end

function SuperMagicBird2024:onPrepareSlpRightUpper(event)
    if not self:isUpdateVer1Available() then return end

    -- local isFail = false
    local runtime = event:getRuntime()
    if not runtime then return end
    if runtime:isRetryBeforeFail() then
        -- 玩家主动唤起的重玩（点击唤起重玩面板），此时打关还没有失败
        -- 未失败的重玩，不展示超鸟入口Icon
        return
    -- elseif runtime:isRetryAfterFail() then
    --     -- 打关失败后的重玩
    --     isFail = true
    end

    local eventData = event:getOrigin()
    local delegate = eventData.slpCreateDelegate
    if not delegate then return end

    local nodeData = self:_getSlpEntryIconData(runtime)
    if not nodeData then return end

    delegate.nodeConfig:setWhole(UBFSuperMB2024NodeId.SLP_RIGHT_UPPER, {
        logicId = UBFSuperMB2024LogicId.SLP_RIGHT_UPPER,
        parentNodeId = UBFSlpNodeId.RIGHT_UPPER,
        enterOrder = 2,
        slpRightUpperData = nodeData,
    })

    event:setGroupBlock()
end

function SuperMagicBird2024:_getSlpEntryIconData(runtime)
    local modContextData = self:_getModContextData(runtime)
    if not modContextData.enabledInLevel then return end

    local nodeData = {}
    local maxProgress = modContextData.activationRequiredWins or 8
    local currProgress = modContextData.activationCurrentWins or 0

    if modContextData.smbEffective then
        nodeData["iconIsActive"] = true

        nodeData["iconProgressNew"] = maxProgress
        nodeData["iconProgressOld"] = maxProgress
        nodeData["iconMaxProgress"] = maxProgress
    else
        nodeData["iconProgressNew"] = currProgress
        nodeData["iconProgressOld"] = currProgress
        nodeData["iconMaxProgress"] = maxProgress
    end
    nodeData["checkActResourceLoadedFunc"] = modContextData.checkActivityResourceLoaded
    nodeData["hasEntryIconGuide"] = modContextData.hasEntryIconGuide
    nodeData["onPopEntryGuide"] = modContextData.onPopEntryGuide
    nodeData["realGiftEntryState"] = UBFHelper:deepClone(modContextData.realGiftEntryState or {})

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


    local lostSuperMB = false   -- 是否断鸟

    -- 打关结束后实时Icon进度数据已重置，需要从刚才打关进关时保存的Mod数据中读取之前的数值
    -- 因为此时上一关的Scene还存在，所以能取到相关数据
    local modMgr = UBFGameModManagerOrganizer:getRunningModManager(runtime.sourceId)
    local oldModEnvData = modMgr and modMgr:getModEnvData()
    -- 断鸟了（打关失败/补星失败）
    if oldModEnvData and oldModEnvData.hasSuperPower then
        if not nodeData.iconIsActive then
            lostSuperMB = true
        end
    end

    if lostSuperMB then
        nodeData["isFail"] = true
        nodeData["iconProgressNew"] = 0

        if oldModEnvData and oldModEnvData.entryIconOldProgressVal then
            local oldProgressVal = oldModEnvData.entryIconOldProgressVal
            local maxProgressVal = nodeData.iconMaxProgress or 8
            nodeData["iconProgressOld"] = oldProgressVal
            if oldProgressVal >= maxProgressVal then
                nodeData["iconIsActive"] = true
            end
        end
    end

    self:_applyReviveCardSlpState(
        nodeData,
        modContextData.reviveCardSlpState,
        "initial"
    )
    if nodeData.state == UBFSuperMB2024SlpEntryState.ACTIVATED then
        nodeData.realGiftEntryTipState = self:_getRealGiftEntryTipState()
    end

    return nodeData
end

function SuperMagicBird2024:_getRealGiftEntryTipState()
    local shouldShow = SmbAmfBridge.shouldShowStartPanelEntryTip()
    local message = shouldShow and SmbAmfBridge.getLotteryTicketTip() or nil
    if type(message) ~= "string" or message == "" then
        shouldShow = false
        message = nil
    end

    return {
        shouldShow = shouldShow,
        message = message,
        onShown = function()
            SmbAmfBridge.recordStartPanelEntryTipTaskRound()
        end,
    }
end

function SuperMagicBird2024:_applyReviveCardSlpState(nodeData, reviveCardState, refreshReason)
    nodeData = nodeData or {}
    local maxProgress = nodeData.iconMaxProgress or nodeData.maxProgress or 8
    local currentProgress = nodeData.iconProgressNew or nodeData.currentProgress or 0

    if reviveCardState then
        maxProgress = tonumber(reviveCardState.maxProgress) or maxProgress
        currentProgress = tonumber(reviveCardState.currentProgress) or currentProgress
    end
    if maxProgress <= 0 then maxProgress = 8 end

    local state
    if reviveCardState then
        if reviveCardState.isSuperBirdActive == true then
            state = UBFSuperMB2024SlpEntryState.ACTIVATED
        elseif reviveCardState.reviveCardEnabled == true
            and reviveCardState.canAccumulate == true
            and reviveCardState.hasUsableCard == true
        then
            state = UBFSuperMB2024SlpEntryState.REVIVE_CARD_AVAILABLE
        else
            state = UBFSuperMB2024SlpEntryState.NORMAL_CHARGING
        end
    elseif nodeData.iconIsActive then
        state = UBFSuperMB2024SlpEntryState.ACTIVATED
    else
        state = UBFSuperMB2024SlpEntryState.NORMAL_CHARGING
    end

    nodeData.state = state
    nodeData.currentProgress = currentProgress
    nodeData.maxProgress = maxProgress
    nodeData.cardExpireAt = reviveCardState and reviveCardState.cardExpireAt or nodeData.cardExpireAt
    nodeData.refreshReason = refreshReason or "update"

    if state == UBFSuperMB2024SlpEntryState.ACTIVATED then
        nodeData.iconIsActive = true
        nodeData.iconProgressNew = maxProgress
        nodeData.iconProgressOld = maxProgress
        nodeData.iconMaxProgress = maxProgress
        nodeData.isFail = nil
    elseif state == UBFSuperMB2024SlpEntryState.REVIVE_CARD_AVAILABLE then
        nodeData.iconIsActive = false
        nodeData.iconProgressNew = currentProgress
        nodeData.iconProgressOld = currentProgress
        nodeData.iconMaxProgress = maxProgress
        nodeData.isFail = nil
    elseif refreshReason ~= "initial" then
        nodeData.iconIsActive = false
        nodeData.iconProgressNew = currentProgress
        nodeData.iconProgressOld = currentProgress
        nodeData.iconMaxProgress = maxProgress
        nodeData.isFail = nil
    end
    return nodeData
end

function SuperMagicBird2024:_getRefreshedSlpEntryIconData(reviveCardState, entryData, refreshReason, realGiftEntryState)
    entryData = entryData or {}
    local nodeData = {
        state = entryData.state,
        currentProgress = entryData.currentProgress,
        maxProgress = entryData.maxProgress,
        cardExpireAt = entryData.cardExpireAt,
        iconIsActive = entryData.iconIsActive,
        iconProgressNew = entryData.iconProgressNew,
        iconProgressOld = entryData.iconProgressOld,
        iconMaxProgress = entryData.iconMaxProgress,
        realGiftEntryState = UBFHelper:deepClone(realGiftEntryState or entryData.realGiftEntryState or {}),
        realGiftEntryTipState = UBFHelper:deepClone(entryData.realGiftEntryTipState or {}),
    }

    if not reviveCardState then
        if refreshReason == "expired" then
            nodeData.state = UBFSuperMB2024SlpEntryState.NORMAL_CHARGING
            nodeData.cardExpireAt = 0
            nodeData.iconIsActive = false
        end
        nodeData.refreshReason = refreshReason
        if nodeData.state == UBFSuperMB2024SlpEntryState.ACTIVATED then
            nodeData.realGiftEntryTipState = self:_getRealGiftEntryTipState()
        end
        return nodeData
    end

    nodeData = self:_applyReviveCardSlpState(nodeData, reviveCardState, refreshReason)
    if nodeData.state == UBFSuperMB2024SlpEntryState.ACTIVATED then
        nodeData.realGiftEntryTipState = self:_getRealGiftEntryTipState()
    end
    return nodeData
end

-- 加五步面板超鸟主题需要的数据
function SuperMagicBird2024:onUBFAddFivePanelGetEntryData(event)
	local eventData = event:getOrigin()
    if eventData.actKey == "SuperMagicBird2024" then
        local modEnvData = self:getModEnvData()
        if UBFAddStepSuperMBUtil:isAddFiveEntryAvailable(modEnvData) then
            local currWinStreakNum = modEnvData.currWinStreakNum
            local maxWinStreakNum = modEnvData.maxWinStreakNum
            if currWinStreakNum and maxWinStreakNum then
                eventData.addFiveData = {
                    currWinComboCount = currWinStreakNum,
                    histroyMaxWinComboCount = maxWinStreakNum,
                    difficultyFlag = eventData.difficultyFlag
                }
            end
        end
    end
end

-- 获取关卡内基础&调节等一些信息，用于内部人员在线上包上查看
function SuperMagicBird2024:onGetUserDebugInfo(event)
    local eventData = event:getOrigin()
    local infos = eventData.infos
    if not infos then return end

    local Meta = require "amf.feature.localactivity.supermagicbird.config.SuperMagicBirdConst"

    local levelInfo, modEnvData = self:getActInLevelData()
    local superCatchData = self.actData.superCatchData
    if not superCatchData then return end

    local adjustData = superCatchData.adjustData

    local bdCurLvl
    local noBirdNum
    local costenough
    local bdAdjustGroup
    local bdadjust
    local costcur
    local costneed
    local costhigh
    local costlast
    local proReward
    local proRewardConfig

    if adjustData and adjustData.actInfos and adjustData.baseInfos then
        local actInfos = adjustData.actInfos
        bdCurLvl = actInfos.activeWinStreakNum
        noBirdNum = actInfos.passTopNums
        costenough = 0

        local fuuuversion = actInfos.fuuuVersion
        if fuuuversion == nil then fuuuversion = Meta.fuuuVersion.kV1 end

        local maintenanceId
        local group
        if fuuuversion == Meta.fuuuVersion.kV2 then
            -- 新超鸟调节
            maintenanceId = 1280
            group = self.actData.adjustGroupV2
            bdAdjustGroup = string.format("%s-%s", maintenanceId, group)

            bdadjust = actInfos.fuuuNum

            local adjustInfo2025 = actInfos.adjustInfo2025 or {}
            proReward = adjustInfo2025.proReward
            proRewardConfig = adjustData.baseInfos.proReward

            costcur = actInfos.costCur or 0
            costneed = actInfos.costNeed or 0
            costhigh = actInfos.percet80Num
            costlast = actInfos.money or 0
            if costcur + costlast >= costneed then
                costenough = 1
            end
        elseif fuuuversion == Meta.fuuuVersion.kV1 then
            -- 老超鸟调节
            maintenanceId = 1205
            group = self.actData.adjustGroup
            bdAdjustGroup = string.format("%s-%s", maintenanceId, group)

            bdadjust = modEnvData.oldFuuuNum
        end
    end

    infos.addInfo("userTag", "bdCurLvl", bdCurLvl, "带超鸟连胜次数", 5)
    infos.addInfo("userTag", "noBirdNum", noBirdNum, "不带鸟累积进度", 6)
    infos.addInfo("userTag", "costenough", costenough, "新超鸟调节达标状态", 7)

    infos.addInfo("levelGroup", "bdAdjustGroup", bdAdjustGroup, "超鸟调节分组", 2)
    local bdThrowGroup = modEnvData.birdThrowGroup
    if bdThrowGroup == 0 or bdThrowGroup == nil then
        bdThrowGroup = "1315-OFF"
    else
        bdThrowGroup = "1315-ON"..tostring(bdThrowGroup)
    end
    infos.addInfo("levelGroup", "bdThrowGroup", bdThrowGroup, "超鸟充能器分组", 3)

    infos.addInfo("diffFix", "bdadjust", bdadjust, "超鸟最终涨幅", 6)
    infos.addInfo("diffFix", "proReward", proReward, "超鸟保护期", 16)
    infos.addInfo("diffFix", "proRewardConfig", proRewardConfig, "超鸟保护期配置值", 17)

    infos.addInfo("details", "costcur", costcur, "costcur", 9)
    infos.addInfo("details", "costneed", costneed, "costneed", 10)
    infos.addInfo("details", "costhigh", costhigh, "costhigh", 11)
    infos.addInfo("details", "costlast", costlast, "costlast", 12)
end

return SuperMagicBird2024
