local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local Manager = class("BlockManager", BaseFeatureManager)

local function shouldReduceAutoPopup(manager)
    return not manager:hasEnteredCurrentPeriod()
        and _G.amfBean("ActivityParticipationMgr"):shouldReduceAutoPopup(manager:getConst().actId)
end

function Manager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
end


-- 功能是否可以启动
function Manager:isEnabled()
    return self:getModel():isDataEnabled()
        and self:isInMainTime()
end

function Manager:isEnabled2()
    return self:getModel():isDataEnabled()
    and (self:isInMainTime() or (self:isInRewardTime() and self:checkNeedSettle()))
end

function Manager:_init()
    self:registerActProps()
    self:callActFunc("registerActInfoUpdate", "onActInfoUpdate")
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
end

function Manager:registerActProps()
    local const = self:getConst()
    for _, v in pairs(const.ActProps) do
        require("amf.feature.localactivity.block.prop.AMFProp_" .. v)
    end
end

function Manager:addActItem(reward)
    local props = self:getConst().ActProps
    if reward.itemId == props.kScoreBuff20 then
        self:getModel():addScoreBuff(1, reward.num)
    elseif reward.itemId == props.kScoreBuff50 then
        self:getModel():addScoreBuff(2, reward.num)
    end
end

function Manager:getCurAvailableBuffAndEndTime()
    local buffExtraRate, buffEndTime = 0, 0
    if self:getModel():getScoreBuff(1) > TimeKit:timeInSec() then
        buffExtraRate = 0.2
        buffEndTime = self:getModel():getScoreBuff(1)*1000
    end

    if self:getModel():getScoreBuff(2) > TimeKit:timeInSec() then
        buffExtraRate = buffExtraRate + 0.5
        buffEndTime = buffEndTime > 0 and math.min(self:getModel():getScoreBuff(1)*1000, self:getModel():getScoreBuff(2)*1000) or self:getModel():getScoreBuff(2)*1000
    end
    UWarning("getCurAvailableBuffAndEndTime", buffExtraRate, buffEndTime)
    return buffExtraRate, buffEndTime
end

-- 获取需要启动的额外功能列表
function Manager:_getExtraPlugsConfigList()
    return {
        {
            key = "AutoPop",
        },
        {
            key = "Download",
        },
        {
            key = "Panel",
        },
        {
            key = "Rewards",
        },
        {
            key = "Request",
            path = {
                plugPath = "amf.feature.localactivity.block.plug.RequestPlug",
            }
        },
        {
            key = "Haptics",
            path = {
                plugPath = "amf.feature.localactivity.block.plug.HapticsPlug",
                const = self:_getConstPath()
            },
        },
        {
            key = "ActSend",
            path = {
                plugPath = "amf.feature.localactivity.block.plug.BlockSendPlug",
            }
        },
    }
end

function Manager:_getAutoPopConfigList()
    return {
        {
            checkPoint = PopupCheckPoint.BLOCK_STAGE4_POP,
            actId = self:getConst().actId,
            stages = {AutoPopupConst.PopStage.STAGE_FOUR},
            check = function()
                if not self:isActivitySupported(self:getConst().actId) then return false end
                if not self:isEnabled() then return false end
                return not shouldReduceAutoPopup(self)
                    and (self:checkCanPop() == true
                        or not self:getFlagFromLocalByKey("MainPanelShow", true))
            end,
            pop = function(_, onPopOver)
                return function()
                    if not self:isEnabled() then
                        safeRunCall(onPopOver)
                        return
                    end
                    if not self:getFlagFromLocalByKey("MainPanelShow", true) then
                        self:setFlagToLocalByKey("MainPanelShow", true, true)
                        self:callActFunc("openActivity", {
                            failCallback = onPopOver,
                            endCallback = onPopOver,
                            extra = {},
                        })
                        return
                    end
                    if self.showYinliuStage4 then
                        self:showYinliuStage4(onPopOver)
                    else
                        safeRunCall(onPopOver)
                    end
                end
            end,
        },
    }
end

function Manager:onActInfoUpdate(evt)
    local data = evt:getData()
    local fromServer = data.fromServer
    if not fromServer then return end
    local actInfos = data.actInfos or {}
    local actInfo = actInfos[tostring(self:getConst().actId)]
    if not actInfo then return end

    local extra = self:callActFunc("getActInfoExtraData")
    if extra then
        local time = {
            beginTime = extra.beginTime,
            mainBeginTime = extra.beginTime,
            mainEndTime = extra.endTime,
            endTime = extra.rewardEndTime
        }
        local oldMainBeginTime = self:getModel():getMainBeginTime()
        if math.floor(tonumber(extra.beginTime) / 1000) ~= oldMainBeginTime then
            self:getModel():clearData()
            self:getModel():updateTimeInfo(time)
            self:getModel():setPeriodId(extra.periodId)
            -- icon倒计时 拿到时间后再刷一次
            local actIcon = self:callActFunc("getActIcon")
            if actIcon and not actIcon.isDisposed then
                actIcon:updateCountDown()
            end
        end
    end
end

-- 获取常量路径
function Manager:_getConstPath()
    return "amf.feature.localactivity.block.const.BlockConst"
end

-- 获取model路径
function Manager:_getModelPath()
    return "amf.feature.localactivity.block.model.BlockModel"
end

function Manager:loadRes(delegate)
    delegate = delegate or {}
    if not delegate.resList then
        safeRunCall(delegate.failCallback)
        return
    end
    self:callDownloadFunc("getAssetsUtil"):loadMiniFiles(delegate.resList)
        :next(delegate.successCallback, delegate.failCallback)
end

-- 同步所有数据
function Manager:updateData(data, fromServer)
    if not data then return end
    self:getModel():fromServer(data)

    self:updateIconProgress()
end

--打关结束时更新数据
function Manager:updatePassLevelData(data, collectionCount, collectionMap, passLevelData)
    local modEnvData = data.modEnvData
    if data.settleMentState then
        local mainLevelCollectionCount = collectionMap[tostring(self:getConst().mainLevelCollectionId)] or 0
        self:getModel():addCollectionNum(mainLevelCollectionCount)
        self:onCollectionAdd(mainLevelCollectionCount)
    end
end
--------------------- icon ---------------------
function Manager:updateTipView()
    if not self:isEnabled2() then return false end

    self:callActFunc("updateTipView")
    self:updateIconProgress()
end

function Manager:hasReward()
    if not self:isEnabled2() then return false end
    return (self:isInMainTime() and self:canGetRewards())
        or (self:isInRewardTime() and self:checkNeedSettle())
end

function Manager:getMsgNum()
    if not self:isEnabled() then return 0 end
    return self:getModel():getCollectionNum()
end

function Manager:checkNeedSettle()
    return self:getModel():getConvert()
end

function Manager:canGetRewards()
    return self:getModel():canGetRewards()
end

function Manager:passDayRefreshData()
    self:getModel():passDayRefreshData()
end

function Manager:updateIconProgress()
    local icon = self:callActFunc("getActIcon")
    if icon then
        icon:updateProgressShow(self:getModel():getScore())
    end
end

-- 协议相关
function Manager:addLaunchInfo(...)
    self:callRequestFunc("addLaunchInfo", ...)
end

function Manager:getCanSendList()
    return self:callRequestFunc("getCanSendList")
end

function Manager:setCanSenListSuccess(...)
    self:callRequestFunc("setCanSenListSuccess", ...)
end

function Manager:setCanSenListSending(...)
    self:callRequestFunc("setCanSenListSending", ...)
end

function Manager:clearLaunchAndMergeList()
    self:callRequestFunc("clearLaunchAndMergeList")
end

-- 震动
function Manager:playHaptics(type)
    self:callHapticsFunc("playHaptics", type)
end
--------------------- 调用接口 ---------------------
function Manager:getMainEndTime()
    return self:getModel():getMainEndTime()
end

function Manager:getEndTime()
    return self:getModel():getEndTime()
end

--是否是主活动期
function Manager:isInMainTime()
    return self:getModel():isInMainTime()
end

--是否是领奖期
function Manager:isInRewardTime()
    return self:getModel():isInRewardTime()
end

-- 检测引导标记
function Manager:hasGuideIndex(index, checkLocalData)
    local hasIndex = self:getModel():hasGuide(index)

    if checkLocalData == nil then checkLocalData = false end
    if checkLocalData then
        local hasLocal = self:getFlagFromLocalByKey("LocalGuideId" .. index, false)
        if hasLocal then
            if not hasIndex then self:addGuideIndex(index) end
            hasIndex = true
        end
    end
    return hasIndex
end

-- 设置引导标记
function Manager:addGuideIndex(index, needSaveLocal)
    self:getModel():setGuide(index)

    if needSaveLocal == nil then needSaveLocal = false end
    if needSaveLocal then
        self:setFlagToLocalByKey("LocalGuideId"..index, false, true)
    end

    local ActCommonHttp = require 'amf.middleware.activity.http.ActCommonHttp'
    ActCommonHttp:setActGuideFlag(self:getConst().actId, index)
end

function Manager:getLocalKey(key,needTime)
    if needTime then
        return key .. tostring(TimeKit:getDayStartTimeByTS(TimeKit:timeInSec()))
    else
        return key
    end
end

function Manager:setFlagToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = true end
    local keyStr = self:getLocalKey(key, needTime)
    self:getModel():setLocalCache(keyStr, value)
end

function Manager:getFlagFromLocalByKey(key, needTime)
    local keyStr = self:getLocalKey(key, needTime)
    return self:getModel():getLocalCache(keyStr)
end

function Manager:hasEnteredCurrentPeriod()
    local mainEndTime = self:getMainEndTime()
    return (tonumber(mainEndTime) or 0) > 0
        and self:getFlagFromLocalByKey("autoPopReduceEnteredEndTime", false) == mainEndTime
end

---------------------  场景强弹 ---------------------

function Manager:onCollectionAdd(num)
    local count = self:getModel():getLocalCache('yinliuCount') or 0
    self:getModel():setLocalCache("yinliuCount",num + count)
end

function Manager:createCollectionIcon()
    return UICreateUtil:createSpriteFile("amf/activity/block/materials/block.png")
end

function Manager:getNowProgressRewards()
    local bGetFinal = self:getModel():getFinalReward()
    local rewards
    local rewardPoint
    if not bGetFinal then
        rewardPoint = 2
        rewards = self:getModel():getFinalRewards()
    else
        rewardPoint = 3
        local bFMJ = _G.amfBean("UserStateManager"):isFMJ()
        rewards = self:getModel():getProgressRewards(nil, not bFMJ)
    end
    local plug = self:_getPlug("ActSend")
    rewards = plug:replaceRewards(rewards,rewardPoint,self.mapId)
    local extraRewards = plug:getExtraRewards(rewardPoint,self.mapId)
    rewards = table.union(rewards,extraRewards)
    return rewards
end

function Manager:showYinliuStage4(done)
    if not self:isEnabled() then safeRunCall(done) return end
    self:loadRes({
        resList = {
            "amf/activity/block/materials/block.png"
        },
        successCallback = function()
            self:doShowYinliuStage4(done)
        end,
        failCallback = done
    })
end

function Manager:openActivity(closeCallback, extra, userClick)
    self:callActFunc("openActivity", {
        failCallback = closeCallback,
        endCallback = closeCallback,
        extra = extra,
        userClick = true,
    })
end

function Manager:doShowYinliuStage4(done)
    if not self:isEnabled() then safeRunCall(done) return end
    local DrainagePanelVM = require 'amf.middleware.ui.kit.panel.second.DrainagePanelVM'
    local vm
    local goCall = function()
        self:callActFunc("openActivity", {
            failCallback = done,
            endCallback = done,
            extra = {
                from = "drainage_collect_obtain"
            },
            userClick = true,
        })
    end

    local showRewards = self:getNowProgressRewards()
    local num = self:getModel():getCollectionNum()
    local collectionIcon = self:createCollectionIcon()
    vm = DrainagePanelVM.Builder:new()
    :setTitle("方块消消")
    :setNumButton('去参与', nil, goCall)
    :pushDesc('您已获得了')
    :pushDesc(collectionIcon)
    :pushDesc(_G.YH_REF_MAP.x .. tostring(num) .."，\n快去方块消消领奖吧！")
    :pushBlock(showRewards,'海量好礼')
    :setCloseCallback(done)
    :build()
    self:callPlug("Panel", "managePanelVM",vm)
    vm:popout()

    self:getModel():onYinliuPopout()
    DcUtil:UserTrack({
        category = 'block_remove',
        sub_category = 'attract_show',
    })
end

function Manager:checkCanPop()
    if not self:isEnabled() then return end
    local yinliuTimes = self:getModel():getLocalCache('yinliuTimes') or 0
    local count = self:getModel():getLocalCache('yinliuCount') or 0
    local num = self:getModel():getCollectionNum()
    if yinliuTimes == 0 then
        return num >= 30
    else
        return yinliuTimes <= 2 and (count >= 20 and num >= 30)
    end
end


---------------------------------- CUSTOM_GAIN ----------------------------------

function Manager:_onCustomGain(event)
    local reward = event:getData()
    local Const = self:getConst()
    local id = reward.itemId
    if id == Const.ActProps.kScoreBuff20
        or id == Const.ActProps.kScoreBuff50 then
        self:addActItem(reward)
    end
end

return Manager
