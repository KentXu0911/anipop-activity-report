local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")

---@class Recall2025Manager : BaseFeatureManager
local Manager = class("Recall2025Manager", BaseFeatureManager)

function Manager:setActivityMgr(activityMgr)
    self._activityMgr = activityMgr
end

function Manager:_init()
    self:registerEvent()
    self:initLoginTime()
    self:initActData()
end

function Manager:initActData()
    local actInfo = self._activityMgr:getActInfo(self:getConst().actId)
    if actInfo and actInfo.extra and type(actInfo.extra) == 'string' then
        local extra = actInfo.extra
        local data = table.deserialize(extra)
        self:getModel():assignData(data)
    end
end

function Manager:registerEvent()
    IconTipEventCenter:register(IconTipEvent.CHECK_ICON_TIP, self.onActCheckIconTip, self)
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
end

-- 获取需要启动的额外功能列表
function Manager:_getExtraPlugsConfigList()
    return {{
        key = "Download"
    }, {
        key = "Panel"
    }}
end

function Manager:_getConstPath() return "amf.feature.recall.recall2025.const.Recall2025Const" end

function Manager:_getModelPath() return "amf.feature.recall.recall2025.model.Recall2025Model" end

-- 处理强弹(场景4)
function Manager:onActEnterStage4()
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.RECALL_2025_STAGE4)
    end

    if not self:isEnabled() then return end

    if not self:getModel():checkTodayRightsGot() then return end

    if self:checkCanUse20Buff() then return end

    -- 关卡失败弹挽留
    if not self:getLocalCache("stage4_fail_pop") and self._lastFailed then
        local function creator()
            if not self:isIconEnabled() then
                onHandleOver()
                return
            end
            self:openMainPanel2(false, onHandleOver, {
                stage = AutoPopupConst.PopStage.kEnterFromLevel2nd
            })
        end
        _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.RECALL_2025_STAGE4, creator)
        self:setLocalCache("stage4_fail_pop", true, true)
    end

    self._lastFailed = false
end

function Manager:onActCheckIconTip(event)
    if _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then return end

    if not self:isEnabled() then return end

    local data = event:getData()
    if data.stage ~= "STAGE_THREE" then return end
    
    local icon = self.actPlug:getActIcon()
    if icon and not icon.isDisposed then
        if self:getModel():checkTodayRightsGot() 
            and not self:getModel():checkRightsAllGot() 
            and not self:checkCanUse20Buff() then
                local delegate = {}
                delegate.iconKey = tostring(self:getConst().actId)
                delegate.iconType = IconTipType.MESSAGE
                delegate.creatorDelegate = {
                    tipsType = HomeIconTipsType.ONLY_TEXT,
                    text = "每日领超强道具",
                }
                delegate.priority = "S"
                delegate.duration = 5
                delegate.daily = true
                delegate.limit = 1
                IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, delegate)
        end
    end
end

--
function Manager:onActPlayLevelEnd(event)
    local data = event:getData()
    if not data.isWin then self._lastFailed = true end
end

function Manager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().actId)]

    if fromServer and actInfo and actInfo.extra and type(actInfo.extra) == 'string' then
        local extra = actInfo.extra
        local data = table.deserialize(extra)
        self:getModel():assignData(data)
    elseif fromServer and not actInfo then
        self:getModel():reset()
    end
end

-------- 页面需要的 数据 和 方法
function Manager:initLoginTime()
    local day = self:getModel():getDayFrom1970()
    local lastDay = self:getModel():getLocalCache("loginDay") or 0
    if lastDay == 0 or lastDay ~= day then self:getModel():setLocalCache("loginDay", day) end

    self.diffTime = day - lastDay
end

--- 活动结束时间
function Manager:getActRealEndTime() return self:getModel():getActRealEndTime() end

--- 活动Main结束时间
function Manager:getMainEndTime() return self:getModel():getMainEndTime() end

--- 获取当前天数
function Manager:getBonusDayCount() return self:getModel():getConfigByKey("maxBonusCount") or 0 end

-- 获取分组
function Manager:getGroup() return self:getModel():getDataByKey("group") end

function Manager:getUnlockDesc()
    local maxBonusCount = self:getModel():getConfigByKey("maxBonusCount") or 0
    return "回归" .. maxBonusCount .. "日可每日免费解锁区域1次"
end

function Manager:dc(subCategory, t1, t2, t3, t4, extraData)
    local params = {
        category = "back_step",
        sub_category = subCategory,
        t1 = t1,
        t2 = t2,
        t3 = t3,
        t4 = t4
    }

    for i, v in pairs(extraData or {}) do params[i] = v end
    DcUtil:UserTrack(params)
end

---------------------------------- icon角标逻辑 ----------------------------------
-- 奖字
function Manager:updateTipView() self.actPlug:updateTipView() end

-- 主icon奖字
function Manager:hasReward() return self:checkCanGetRightsToday() end

-- 主icon数字
function Manager:getShowMsgNum() return 0 end

function Manager:isEnabled() 
    if EnvUtil:isMiniGame() then
        return false
    end
    return self:isDataEnabled() and self:isInMainTime() 
end

function Manager:isEnabled2() return self:isDataEnabled() and (self:isInMainTime() or self:isInRewardTime()) end

function Manager:isIconEnabled()
    -- 明天没得领 今天领完了 且buff用完了
    if not self:getModel():checkCanGetRightsTomorrow() and self:getModel():checkTodayRightsGot() and
        not self:checkCanUse20Buff() then return false end
    return (self:isInMainTime() and not self:getModel():checkRightsAllGot()) or self:checkCanUse20Buff()
end

function Manager:isDataEnabled() return self:getModel():isDataEnabled() end

-- 是否是主活动期
function Manager:isInMainTime() return self:getModel():isInMainTime() end

function Manager:isInRewardTime() return self:getModel():isInRewardTime() end

function Manager:isNoNetwork() return not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() end

function Manager:getTodayRightsHTTP(successCallback, failCallback, cancelCallback)
    if self:isNoNetwork() then
        safeRunCall(failCallback)
        return
    end

    self:getModel():requestCallback2025Bonus():next(function(event)
        safeRunCall(successCallback, event) 
        self:dc("addScore_bottle")
    end, function(response)
        if response:isCancel() then
            safeRunCall(cancelCallback)
        else
            CommonTip:showErrorTip(response)
            safeRunCall(failCallback)
        end
    end)
end

------------------------------- 面板 -------------------------------
-- 打开主面板（可以领奖的那个）
function Manager:openMainPanel(userClick, closeCallback, extra)
    local isFirst = false
    local dayCount = 0
    local popedId = self:getModel():getLocalCache("popedId")
    local roundId = self:getModel():getDataByKey("roundId", 0)

    if extra and extra.stage == AutoPopupConst.PopStage.STAGE_TWO then
        if not self:getModel():checkTodayRightsGot() then
            local bonusDays = self:getModel():getDataByKey("bonusDays", {})
            if table.isEmpty(bonusDays) and roundId ~= popedId then isFirst = true end
        end
    end
    dayCount = self:getModel():getDayCount()
    local showLong = self.diffTime > 3

    local delegate = {
        userClick = userClick,
        -- 首次弹出展示
        isFirst = isFirst,
        -- 第几天
        dayCount = dayCount,

        closeCallback = closeCallback,

        showLong = showLong,

        canEnter = extra and extra.canEnter
    }

    self:getModel():setLocalCache("popedId", nil, roundId)

    local vm = require("amf.feature.recall.recall2025.view.MainPanelVM")
    vm:create(delegate):popout()
end

-- 打开主面板（非领奖状态纯展示的那个）
function Manager:openMainPanel2(userClick, closeCallback, extra)
    local delegate = {
        buffStep20EndTs = tonumber(self:getModel():getDataByKey("buffStep20EndTs", 0)),
        mainEndTs = self:getModel():getMainEndTime(),
        maxBonusCount = self:getModel():getConfigByKey("maxBonusCount") or 0,
        dayCount = self:getModel():getDayCount(), -- 第几天
        userClick = userClick,

        closeCallback = closeCallback
    }

    local cls = require("amf.feature.recall.recall2025.view.MainPanel2VM")
    local panel = cls:create(delegate)
    panel:popout()
end

function Manager:tryOpenMainPanel(userClick, closeCallback, extra)
    if not self:isEnabled2() then
        safeRunCall(closeCallback)
        return
    end

    -- 领完权益就开展示面板
    if self:checkCanGetRightsToday() then
        self:openMainPanel(userClick, closeCallback, extra)
    else
        if not userClick then
            safeRunCall(closeCallback)
        else
            self:openMainPanel2(userClick, closeCallback, extra)
        end
    end
end

------------------------------- 关卡外 -------------------------------
function Manager:checkCanGetRightsToday()
    if not self:isEnabled() then return false end
    return not self:getModel():checkTodayRightsGot() and not self:getModel():checkRightsAllGot()
end

-- 是否在回流状态
function Manager:checkInRecallState()
    local level = _G.getTopPassedLevelId()
    return level >= 100 and _G.amfBean("AMFRecallManager"):checkReturnBackState(_G.RecallId.COMMON_FOURTEEN_DAY)
end

-- 今天是否可以用免费解锁
function Manager:checkTodayCanUseUnlockFree()
    if not self:isEnabled() then return false end
    if self:isNoNetwork() then return false end
    return self:getModel():checkTodayRightsGot() and not self:getModel():checkTodayUnlockFreeUsed()
end

function Manager:checkCanUse20Buff() return self:getModel():checkCanUse20Buff() end

function Manager:setTodayUnlockFreeUsed() self:getModel():setTodayUnlockFreeUsed() end

function Manager:setLocalCache(key, value)
    self:getModel():setLocalCache(key, value)
end

function Manager:getLocalCache(key)
    return self:getModel():getLocalCache(key)
end

function Manager:getMaxBonusCount()
    return self:getModel():getConfigByKey("maxBonusCount", 0)
end

function Manager:autoStartLevel(callback)
    local levelId = _G.getTopLevelId()
    local playLevelContext = PlayLevelContext.new(levelId, PlayLevelContext.PlayType.AUTO_START_LEVEL)
    playLevelContext:setAbortCallback(callback)
    _G.amfTransaction(TransactionEvent.PLAY_LEVEL, playLevelContext)
end

------------------------------- 关卡内 -------------------------------
function Manager:isInLevelEnabled()
    if not self:isEnabled2() then return false end
    return true
end

--返回关卡内打关所需要的数据
function Manager:getInLevelActData(levelId)
    local group = self:getGroup()
    local inLevelActData = {
        isHasStepBuff = self:checkCanUse20Buff(),
        addStepCount = 20,
        diffIndex = group == "ON3" and 1 or 2,
    }
    return inLevelActData
end

--打关结束时更新数据
function Manager:updatePassLevelData(data, addScore, collectionMap, passLevelData)

end

return Manager
