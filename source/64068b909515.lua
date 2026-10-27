local FullStarLevelLibManager = class("FullStarLevelLibManager")
local FullStarLevelLibEventCenter = require("amf.feature.fullstarlevellib.event.FullStarLevelLibEventCenter")
local Model = require("amf.feature.fullstarlevellib.model.FullStarLevelLibModel")
local Meta = require("amf.feature.fullstarlevellib.config.FullStarLevelLibConst")
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local CloudEventCenter = require"amf.feature.mainscene.module.cloud.event.CloudEventCenter"
require("amf.feature.fullstarlevellib.dc.FullStarLevelLibDC")

FullStarLevelLibManager.ACT_ID = 5312

function FullStarLevelLibManager:ctor()
end

function FullStarLevelLibManager:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
end

function FullStarLevelLibManager:setActivityMgr(activityMgr)
    self._activityMgr = activityMgr
end

function FullStarLevelLibManager:initialize()
    self.model = Model:create("FullStarLevelLibManager")

    self.meta = Meta

    -- local data = self:getParsedActInfo()
    -- if data then
    --     self:updateData(data)
    -- end

    self:registerEvents()
end

function FullStarLevelLibManager:updateData(data)
    self.model:fromServer(data)
end

function FullStarLevelLibManager:clearData()
    self:removeStartPanelAlarm()
    self.model:reset()
end

function FullStarLevelLibManager:registerEvents()
    FullStarLevelLibEventCenter:registerFeature(self)
    FullStarLevelLibEventCenter:registerSystem(self)

    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    CloudEventCenter:register(CloudEventConst.TOP_DOWN_PART_CREATE,self.addMainsSceneCloudButton,self)
end

function FullStarLevelLibManager:addMainsSceneCloudButton()
    local FullStarLevelLibCloudBtn = require"amf.feature.fullstarlevellib.view.FullStarLevelLibCloudBtn"
    local node = FullStarLevelLibCloudBtn:create()
    _G.amfBean("CloudManager"):addDownPartNode(node,"FullStarLevelLibCloudBtn")
end

function FullStarLevelLibManager:getModel()
    return self.model
end

-- 活动是否可以展示
function FullStarLevelLibManager:isBaseEnabled()
    if not self:getModel():isDataEnabled() then
        return false
    end
    if not self:getModel():isTimeEnabled() then
        return false
    end
    if not self:getModel():isVersionEnabled() then
        return false
    end

    return true
end

-- 活动还剩一分钟，后端数据已刷新，不可玩
function FullStarLevelLibManager:oneMinuteLeft()
    local startTime = self:getModel():getValue("startTime")
    local endTime = self:getModel():getValue("endTime")
    if not startTime or not endTime then
        return false
    end
    local nowTime = TimeKit:timeInMillis()
    return endTime - nowTime < 60 * 1000
end

-- stage4是否可以强弹
function FullStarLevelLibManager:checkStage4CanPop()
    return self._shouldPopupUnlock
end

function FullStarLevelLibManager:setShouldPopupUnlock(shouldPopupUnlock)
    self._shouldPopupUnlock = shouldPopupUnlock
end

-- 如果剩余关卡数量少于10个，就开始尝试拉取主info
function FullStarLevelLibManager:tryRequestMainInfo()
    -- 活动没开
    if not self:canPlay() then
        return
    end

    -- 如果离线，自然不发
    if _G.amfBean("NetworkStatusManager"):getNetworkStatus() == _G.NetworkConst.NetworkStatusDes.NONETWORK then
        return
    end

    -- 第一次拉
    if (not self.hasUpdateFirstTime) or self:getModel():isLevelTooLess() then
        -- 不管成没成功，拉一次就完事
        self.hasUpdateFirstTime = true
        self:requestMainInfo()
    end
end

-- 获取解析的actInfo
function FullStarLevelLibManager:getParsedActInfo()
    local actInfo = self._activityMgr:getActInfo(self.ACT_ID)

    if actInfo and actInfo.extra and type(actInfo.extra) == 'string' then
        local extra = actInfo.extra
        local data = table.deserialize(extra)
        return data
    end
end

-- 主info
function FullStarLevelLibManager:requestMainInfo(successCallback, failCallback, cancelCallback, noLoading)
    if self.isRequesting then
        return
    end

    local request = require("amf.feature.fullstarlevellib.http.RandomChallengeMainInfo")
    self.isRequesting = true

    local function onSuccess(event)
        local data = event:getData()
        self.isRequesting = false
        self:updateData(data)
        safeRunCall(successCallback)

        if not self.firstUpdateMainInfo then
            FullStarLevelLibEventCenter:dispatch(FullStarLevelLibEvent.FULL_STAR_LEVEL_LIB_FIRST_UPDATE)
            self.firstUpdateMainInfo = true
        end
    end

    local function onFail(event)
        self.isRequesting = false
        safeRunCall(failCallback)
    end

    local function onCancel(event)
        self.isRequesting = false
        safeRunCall(cancelCallback)
    end

    request:post({
        noLoading = noLoading
    }):next(onSuccess, function(response)
        if response:isCancel() then
            onCancel(response)
        else
            onFail(response)
        end
    end)
end

-- passLevel
function FullStarLevelLibManager:onActPlayLevelEnd(event)
    local data = event:getData()

    -- 满星关卡库
    if LevelSceneFunc:isFullLevelLib(data.levelScene) then
        if data.isWin then
            self:getModel():addPassLevelCount()
            self:getModel():resetContinuousLose()
        else
            self:getModel():addContinuousLose()
            self:getModel():resetContinuousWin()
        end
        self:setShouldPopupUnlock(false)
    elseif data.levelType == GameLevelType.kMainLevel then
        self:setShouldPopupUnlock(data.oldStar < 4 and _G.amfBean("UserStateManager"):isColorfulStarFull())
    else
        self:setShouldPopupUnlock(false)
    end
end

function FullStarLevelLibManager:onActCreateResumePanel(evt)
    local data = evt:getData()
    if not data.outData then
        return
    end
    if not LevelSceneFunc:isFullLevelLib(data.levelScene) then
        return
    end

    local outData = data.outData
    local levelIndex = self:getModel():getNextLevelCount()
    outData.levelNameStr = "随机挑战第" .. levelIndex .. "关"
end

function FullStarLevelLibManager:onActEnterStage4(data)
	if not self:checkStage4CanPop() then return end

    local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.FULL_STAR_LEVEL_LIB)
	end

	local function creator()
        if not self:checkStage4CanPop() then
            safeRunCall(onHandleOver)
            return
        end
        local MainSceneEventCenter = require 'amf.feature.mainscene.core.event.MainSceneEventCenter'
		MainSceneEventCenter:dispatch(MainSceneEvent.Trunk.MOVE_TRUNK_TO, {
            levelId = getTopLevelId(),
            callback = function()
                -- 检查 FullStarLevelLibCloudBtn 是否存在
                local cloudDownLayoutLayer = _G.amfBean("CloudManager"):getCloudDownLayoutLayer()
                local hasCloudBtn = cloudDownLayoutLayer and
                                   cloudDownLayoutLayer.nodeMap and
                                   cloudDownLayoutLayer.nodeMap["FullStarLevelLibCloudBtn"]

                if hasCloudBtn then
                    FullStarLevelLibEventCenter:dispatch(FullStarLevelLibEvent.FULL_STAR_LEVEL_LIB_UNLOCK, {
                        callback = onHandleOver
                    })
                else
                    -- 如果按钮不存在，直接调用 onHandleOver
                    safeRunCall(onHandleOver)
                end
            end,
            duration = 0.1,
        })
	end

	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.FULL_STAR_LEVEL_LIB, creator)
end

function FullStarLevelLibManager:refreshCloud()
    local UnlockEventCenter = require "amf.feature.mainscene.module.areaunlock.event.UnlockEventCenter"
    local UnlockAreaLogic = require "amf.feature.mainscene.module.areaunlock.logic.UnlockAreaLogic"
    local topLevelId = _G.getTopLevelId()
    local cloudId = UnlockAreaLogic:levelIdToCloudId(topLevelId)
    UnlockEventCenter:dispatch(UnlockAreaEvent.Cloud.REFRESH_CLOUD, {
        cloudId = cloudId + 1,
        cloudState = LockedCloudState.STATIC
    })
end

function FullStarLevelLibManager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self.ACT_ID)]

    if actInfo and actInfo.extra and type(actInfo.extra) == 'string' then
        local extra = actInfo.extra
        local data = table.deserialize(extra)
        self:updateData(data)

        self:addStartPanelAlarm()

        self:tryRequestMainInfo()
    else
        if fromServer and not actInfo then
            if self:isBaseEnabled() then
                self:clearData()
                FullStarLevelLibEventCenter:dispatch(FullStarLevelLibEvent.FULL_STAR_LEVEL_LIB_FIRST_UPDATE)
            else
                self:clearData()
            end
        end
    end
end

function FullStarLevelLibManager:onActEnterMainScene()
    self:tryRequestMainInfo()
end

function FullStarLevelLibManager:onSystemEnterForeground()
    self:tryRequestMainInfo()
end

function FullStarLevelLibManager:openStartPanel(userClick, extraData)
    local levelId = self:getModel():getNextLevelId()
    if (not levelId) and userClick then
        CommonTip:showTip("获取关卡信息失败，请重新连接网络")
        return
    end

    local playLevelContext = PlayLevelContext.new(levelId, PlayLevelContext.PlayType.OPEN_SL_PANEL)
    playLevelContext:setLevelScene(UBFLevelSceneType.kFullLevelLibrary)
    playLevelContext:setExtraData(extraData)
    _G.amfTransaction(TransactionEvent.PLAY_LEVEL, playLevelContext)
end

-- 时间到了
function FullStarLevelLibManager:onTimeEnd()
    self:tryCloseStartPanel()
    self.alarmId = nil
end

function FullStarLevelLibManager:addStartPanelAlarm()
    if self.alarmId then
        return
    end

    if not self:canPlay() then
        return
    end

    if not self.tickFunc then
        self.tickFunc = function()
            self:onTimeEnd()
        end
    end

    local endTime = math.floor(tonumber(self:getModel():getValue("endTime") / 1000))
    local nowTime = TimeKit:timeInSec()
    if endTime < nowTime then
        return
    end
    self.alarmId = TimerUtil.addAlarm(self.tickFunc, endTime - nowTime, 1)
end

function FullStarLevelLibManager:removeStartPanelAlarm()
    if not self.alarmId then
        return
    end
    TimerUtil.removeAlarm(self.alarmId)
    self.alarmId = nil
end

-- 关开始面板
function FullStarLevelLibManager:tryCloseStartPanel()
    UBFGlobal:callLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER, "exeOp", UBFSlpOpType.CLOSE)
end

function FullStarLevelLibManager:loadActIntroPanelRes(successCallback, failCallback)
    _G.amfBean("AssetsUtil"):loadMiniFiles({"amf/fullstarlevellib/texture/DescPanel.plist"}):next(
        successCallback, failCallback)
end

----------------------------------------------对外用-------------------------------------------------
function FullStarLevelLibManager:canShowCloud()
    if _G.amfBean("UserStateManager"):isFMJ() then
        return false
    end
    local flag = self:isBaseEnabled()
    local num = self:getModel():getUnlockColorNum() or 0
    return flag and num > 0
end

function FullStarLevelLibManager:canPlay()
    if _G.amfBean("UserStateManager"):isFMJ() then
        return false
    end
    return self:isBaseEnabled() and self:getModel():isLevelCanPlay()
end

function FullStarLevelLibManager:tryOpenStartPanel(userClick, detailPanelParams)
    if not self:canPlay() then
        return
    end
    if self:oneMinuteLeft() then
        if userClick then
            CommonTip:showTip(Localization:getInstance():getText("error.tip.732367"), "negative")
        end
        return
    end

    local function openStartPanel()
        if _G.amfBean("NetworkStatusManager"):getNetworkStatus() == _G.NetworkConst.NetworkStatusDes.NONETWORK then
            self:openStartPanel(userClick, detailPanelParams)
        elseif self:getModel():getNextLevelId() then
            self:openStartPanel(userClick, detailPanelParams)
        else
            self:requestMainInfo(function()
                self:openStartPanel(nil, detailPanelParams, userClick)
            end, nil, nil, not userClick)
        end
    end
    openStartPanel()
end

-- 创建说明面板
function FullStarLevelLibManager:createDescPanel(closeCallback)
    self:loadActIntroPanelRes(function()
        local illustrationPanelVM = require 'amf.middleware.ui.kit.panel.other.IllustrationPanelVM'

        local vm = illustrationPanelVM.Builder.new():setTitle(""):createWithSource(
            "amf.feature.fullstarlevellib.view.uisource.DescPanel_UI.lua"):setDefaultPage(1):setCloseCallback(
            closeCallback):build()

        vm:popout()
    end, closeCallback)
end

-- 创建满星关卡库按钮
function FullStarLevelLibManager:createFullLevelLibButton(refreshFuc)
    local UIButton = require "amf.middleware.ui.kit.component.button.UIButton"

    local button
    button = UIButton:createButton({
        scaleMode = UIButtonConfig.BtnScales.k75,
        widthMode = UIButtonConfig.Widths.kShort,
        str = "随机挑战",
        touchFunc = function()
            if not self:canPlay() then
                safeRunCall(refreshFuc)
                return
            end
            button:stopBorderLightAnimation()
            self:tryOpenStartPanel(true)
        end
    })

    FullStarLevelLibDC:send101OnceADay("full_star", "vine_button_show")

    button:runBorderLightAnimation()
    button:runBreathAnimation()

    return button
end

-- 大藤蔓按钮优化后使用的新锁
function FullStarLevelLibManager:createFullLevelCloudLockNew()
    local node = Node:create()
    local bg = UICreateUtil:createScale9SpriteFile("amf/mainscene/trunk/cloud/material/FullStarLevelLibLockBg.png", nil, true)
    bg:setPreferredSize(CCSizeMake(440, 40))
    local star = Sprite:createWithSpriteFrameName("other/iconV2/ui_icon_star_01_v2")
    star:setScale(0.4)
    star:setPositionX(-146)
    local numLabel = TTFLabel:createAnimalYH(0, 24)
    numLabel:setAnchorPoint(ccp(0.5, 0.5))
    numLabel:setTextColor(hex2ccc4("cf71d2ff"))
    numLabel:enableOutline(hex2ccc4("ffffffff"), 2)
    numLabel:setPositionXY(25, -2)
    node:addChild(bg)
    node:addChild(star)
    node:addChild(numLabel)
    node:setPositionY(-10)

    local context = self
    function node:resetNum()
        if numLabel and not numLabel.isDisposed then
            local unlockStarNum = context:getModel():getUnlockColorNum() * 3
            numLabel:setString("达" .. unlockStarNum .. "颗开启随机挑战")
        end
    end

    return node
end

-- 创建满级云锁
function FullStarLevelLibManager:createFullLevelCloudLock()
    local uiData = require("amf.feature.fullstarlevellib.view.uisource.CloudLockNode_UI.lua")
    local builder = UIBuilder.new(uiData)
    local node, instance = builder:buildUIWithData()

    local context = self
    function node:resetNum()
        if instance.starNumLabel and not instance.starNumLabel.isDisposed then
            local unlockStarNum = context:getModel():getUnlockColorNum() * 3
            instance.starNumLabel:setString("达" .. unlockStarNum .. "颗开启")
            local sortNodeInfos = {}
            table.insert(sortNodeInfos, {
                node = instance.star,
                width = instance.star:getContentSize().width
            })
            table.insert(sortNodeInfos, {
                node = instance.starNumLabel,
                width = instance.starNumLabel:getContentSize().width
            })
            LayoutUtil.sortNodes(sortNodeInfos, IntCoord:create(200, 0), -40)
        end
    end

    node:resetNum()

    return node
end

function FullStarLevelLibManager:getNextLevelId()
    return self:getModel():getNextLevelId()
end

function FullStarLevelLibManager:getLevelDifficultFlagByLevelId(levelId)
    return self:getModel():getLevelDifficultFlagByLevelId(levelId)
end

function FullStarLevelLibManager:getContinuousLose()
    return self:getModel():getContinuousLose()
end

function FullStarLevelLibManager:isDifficultLevel(flag)
    return FsllDifficultFlag.kDifficult == flag
end

------------------------------- 关卡内 -------------------------------
-- --关卡内功能开启的判断条件入口
-- function FullStarLevelLibManager:isInLevelEnabled(data)
--     -- TODO
--     UBFLogE('== isInLevelEnabled ========', tts(data))
--     if not self:isBaseEnabled() then return false end
--     -- local curFullStarState = self:getStarLevelStatus()
--     -- if curFullStarState < StarLevelState.EXCEED then return false end
--     -- if not self:isNextLevel(data.levelId, data.levelScene) then
--     --     return false
--     -- end

--     return true
-- end

function FullStarLevelLibManager:getInLevelActData(levelId)
    local inLevelActData = {}

    inLevelActData.levelIndex = self:getModel():getNextLevelCount()
    inLevelActData.levelFlag = self:getModel():getLevelDifficultFlagByLevelId(levelId)
    inLevelActData.continuousLose = self:getModel():getContinuousLose()
    inLevelActData.continuousWin = self:getModel():getContinuousWin()

    local diffInfo = self:getModel():getLevelDifficultInfoByLevelId(levelId)
    inLevelActData.dcDifficultyLevel = diffInfo and diffInfo.logDifficultyLevel
    inLevelActData.diffPercentile = diffInfo and diffInfo.diffPercentile

    return inLevelActData
end

function FullStarLevelLibManager:onActBeforeStartLevel(data)
    self:clearLevelRewardInLevel()
    if not self:isBaseEnabled() then return end
    local levelReward = self:getModel():getValue("levelReward")
    self:saveLevelRewardInLevel(levelReward)
end

function FullStarLevelLibManager:saveLevelRewardInLevel(levelReward)
    LocalDB:setString("FullStarLevelLibLevelReward", levelReward)
end

function FullStarLevelLibManager:clearLevelRewardInLevel()
    LocalDB:setString("FullStarLevelLibLevelReward", "")
end

function FullStarLevelLibManager:getLevelRewardInLevel()
    local levelReward = LocalDB:getString("FullStarLevelLibLevelReward")
    if levelReward == "" or levelReward == nil then
        return {}
    end

    local tbl = string.split(levelReward, ",")
    local retLevelReward = {}
    for k, v in ipairs(tbl) do
        local data = string.split(v, ":")
        table.insert(retLevelReward, {
            itemId = tonumber(data[1]),
            num = tonumber(data[2])
        })
    end
    return retLevelReward
end

function FullStarLevelLibManager:onActJudgeHasCrashResume(data)
    if not LevelSceneFunc:isFullLevelLib(data.levelScene) then
        return
    end

    -- TODO FSLL
    if not self:isBaseEnabled() then
        data.hasCrashResume = false
        data.crashResumeFailReason = ResumeFailReason.kFullLevelStarLibraryOff
    end
    return true
end

-- 闪退恢复
function FullStarLevelLibManager:onActDoCrashResume(data)
    if not self:isBaseEnabled() then
        return
    end
    if not data then
        return
    end
    if not LevelSceneFunc:isFullLevelLib(data.levelScene) then
        return
    end

    safeRunCall(data.yesCallback)
    return true
end

-- 闪退恢复失败
function FullStarLevelLibManager:onActCrashResumeFailed(event)
    local data = event:getData()
    if not LevelSceneFunc:isFullLevelLib(data.levelScene) then
        return
    end

    if self:isBaseEnabled() then
        self:getModel():addContinuousLose()
        self:getModel():resetContinuousWin()
    end
    return true
end
--------------------------------------------------------------

return FullStarLevelLibManager
