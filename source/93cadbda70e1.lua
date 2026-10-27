local deferred = require "amf.script.sugar.deferred"
require "amf.feature.localactivity.promotelow.config.PromoteLowConst"
local PromoteLowEventCenter = require "amf.feature.localactivity.promotelow.event.PromoteLowEventCenter"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local PromoteLowMgr = class("PromoteLowMgr")

function PromoteLowMgr:ctor()
    self._activityMgr = nil
    self._networkStatusManager = nil
    self._propManager = nil
    self._iconManager = nil
    self._vmMap = {}
end

function PromoteLowMgr:setIconManager(mgr)
    self._iconManager = mgr
end

function PromoteLowMgr:setPropManager(mgr)
    self._propManager = mgr
end

function PromoteLowMgr:setNetworkStatusManager(nsm)
    self._networkStatusManager = nsm
end

function PromoteLowMgr:setActivityMgr(mgr)
    self._activityMgr = mgr
end

function PromoteLowMgr:initialize()
    self.model = require("amf.feature.localactivity.promotelow.model.Model"):create()
    self:updateModelDataByActInfo()
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
    self:registerStarBuff()
    self:tryRequestBuff()
    self:registerEvent()
end

function PromoteLowMgr:registerEvent()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onInfoUpdate, self)
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
end

-- 注册buff道具
function PromoteLowMgr:registerStarBuff()
    if not self._hasRegStarBuff then
        require "amf.feature.localactivity.promotelow.prop.StarBuff"
        self._hasRegStarBuff = true
    end
end

-- 当活动不可用时，buff还是能用的。。。。。
function PromoteLowMgr:syncTimeCfg(timeCfg)
    if not self.model then return end
    if self._syncedTime then return end
    self:setValue("beginTime", timeCfg.beginTime)
    self:setValue("endTime", timeCfg.endTime)
    if not self._hasRequestBuff then
        self:log("frome syncTimeCfg ----", timeCfg.beginTime, timeCfg.endTime)
        self:tryRequestBuff()
    end
    self._syncedTime = true
end

function PromoteLowMgr:getActExtTb()
    local actInfo = self._activityMgr:getActInfo(PromoteLowConst.ACT_ID)
    local extTb = nil
    if actInfo and actInfo.extra and actInfo.extra ~= "" then
        extTb = table.deserialize(actInfo.extra)
    end
    return extTb
end

function PromoteLowMgr:updateModelDataByActInfo(extTb)
    if not self.model then return end
    local extTb = extTb or self:getActExtTb()
    -- TODO TEST 
    -- extTb = {
    --     activityRound = 1,
    --     round = 1,
    --     rewarded = false,
    --     dayList = {1,2,3,4,5,6},
    --     rewardGroupId = "ggg",
    --     currentRoundEndTime = TimeKit:timeInMillis() + 3600,
    --     rewardList = {
    --         {itemId = 14, num = 2},
    --         {itemId = 14, num = 3},
    --         {itemId = 14, num = 4},
    --         {itemId = 14, num = 5},
    --         {itemId = 14, num = 6},
    --         {itemId = PromoteLowConst.StarBuff_ID, num = 10},
    --     }
    -- }
    self.model:updateActInfo(extTb)
end

function PromoteLowMgr:isGroupEnabled()
    local Group = require "amf.feature.localactivity.promotelow.Group"
    if Group:isOff() then
        self:log("isActEnabled --- Group:Off")
        return false
    end
    return true
end

function PromoteLowMgr:isActEnabled()
    if not self:isGroupEnabled() then
        return false
    end
    local actStartTime = tonumber(self:getValue("beginTime")) or 0
    local actEndTime = tonumber(self:getValue("endTime")) or 0
    local curTime = TimeKit:timeInSec()
    if curTime <= actStartTime or curTime >= actEndTime then
        self:log("isActEnabled --- time:error ", curTime, actStartTime, actEndTime)
        return false
    end
    return true
end

function PromoteLowMgr:isModelEnabled()
    local isEnable = self.model and self.model:getTempData("isEnable")
    if not isEnable then 
        return false 
    end
    local forceDisable = self.model:getTempData("forceDisable")
    if forceDisable then 
        return false 
    end
    local rewarded = self:getValue("rewarded")
    if rewarded then
        return false
    end

    if EnvUtil:isApp() then
        -- 如果过了每轮持续时间上限也不可用
        local currentRoundEndTime = self:getValue("currentRoundEndTime") or 0
        if TimeKit:timeInSec() >= currentRoundEndTime then
            return false
        end
    end
    return true
end

function PromoteLowMgr:isEnabled()
    if not self:isActEnabled() then
        self:log("act not enabled ===")
        return false
    end
    if not self:isModelEnabled() then 
        self:log("model not enabled ===")
        return false 
    end
    
    return true
end

function PromoteLowMgr:showErrorTip(evt)
    local errcode
    if type(evt) == 'number' then
        errcode = evt
    elseif type(evt) == 'table' then
        errcode = evt.data or nil
    end
    -- 错误码
    local tipStr = PromoteLowConst.Error[tostring(errcode)]
    if tipStr then
        CommonTip:showTip(tipStr)
    else
        CommonTip:showErrorTip(evt)
    end
end

-- 请求buff
function PromoteLowMgr:tryRequestBuff()
    if not self:isActEnabled() then return end
    self.model:requestBuff():next(function(response)
        local data = response:getData()
        local buffEndTime = data.scoreBuffExpireTime or 0
        self:setValue("scoreBuffExpireTime", buffEndTime)
    end)
    self._hasRequestBuff = true
end

-- 领取奖励
function PromoteLowMgr:requestReward(param)
    local d = deferred.new()
    self.model:requestReward(param):next(function(response)
        local rewards = self:getValue("rewardList") or {}
        if not table.isEmpty(rewards) then
            GainPropData:create()
                :setFeature(PromoteLowConst.DC_FEATURE)
                :setSource(PromoteLowConst.DC_SOURCE)
                :setProps(rewards)
                :execute()
        end 
        self:setValue("rewarded", true) 
        -- 刷新icon
        self:removeActButton()
        d:resolve(rewards)
    end, function(response)
        if not response:isCancel() then
            self:showErrorTip(response)
        end
        local errCode = response:getErrorCode()
        if tonumber(errCode) == 737139 then
            self.model:setTempData("forceDisable", true)
            self:removeActButton()
        end
        d:reject()
    end)

    return d
end

-- 是否可以领奖
function PromoteLowMgr:isCanReward()
    if not self:isEnabled() then return false end
    local rewarded = self:getValue("rewarded")
    if rewarded then return false end
    local forceDisable = self.model:getTempData("forceDisable")
    if forceDisable then return false end
    local dayList = self:getValue("dayList") or {}
    local signCount = table.count(dayList)
    return signCount >= self:getValue("totalDays")
end

function PromoteLowMgr:addVmToMgr(vm)
    self._vmMap[vm] = true
end

function PromoteLowMgr:hasPanel()
    for vm,_ in pairs(self._vmMap) do
        if vm and not vm.isDisposed then
            return true
        end
    end
    return false
end

function PromoteLowMgr:closeAll()
    for vm,_ in pairs(self._vmMap) do
        if vm and not vm.isDisposed then
            vm:close()
        end
    end
    self._vmMap = {}
end

function PromoteLowMgr:getValue(key)
    return self.model and self.model:getValue(key)
end

function PromoteLowMgr:setValue(key, value)
    if self.model then
        self.model:setValue(key, value)
    end
end

function PromoteLowMgr:getLocalValue(key)
    local localValueTb = self.model and self.model:getValue("localValueTb") or {}
    return localValueTb[key]
end

function PromoteLowMgr:setLocalValue(key, value)
    local localValueTb = self.model and self.model:getValue("localValueTb") or {}
    localValueTb[key] = value
    local _ = self.model and self.model:setValue("localValueTb", localValueTb)
end

-- actInfoupdate 事件
function PromoteLowMgr:onInfoUpdate(event)
    -- UError("onActActInfoUpdate  ---")
    self:updateModelDataByActInfo()
end

-- 回到前台
function PromoteLowMgr:onSystemEnterForeground()
    self:tryRequestBuff()
end

-- 过关事件
function PromoteLowMgr:onActPlayLevelEnd(evt)
    local param = evt:getData()
    if not UBFLevelSceneFunc:isMainOrHiddenLevel(param.levelScene) then return end
    if not param.isWin then return end
    local oldStar = param.oldStar or 0
    local star = param.star or 0
    -- 过关&&刷新星级
    if star > oldStar or (LevelSceneFunc and LevelSceneFunc:isFullLevelLib(param.levelScene)) then
        self:addDayList()
    end
end

function PromoteLowMgr:addDayList(dayNum)
    dayNum = dayNum or TimeUtil:getDayIdxSince1970()
    local dayList = self:getValue("dayList") or {}
    if table.exist(dayList, dayNum) then
        return 
    end
    if table.count(dayList) < self:getValue("totalDays") then
        table.insert(dayList, dayNum)
        self:setValue("dayList", dayList)
    end
end

-- 跨天
function PromoteLowMgr:onActPassDay()
    if self:isEnabled() then
        PromoteLowEventCenter:dispatch(PromoteLowEvent.PASS_DAY)
    else
        if self:hasPanel() then
            CommonTip:showTip(PromoteLowConst.Desc.TIP_ACT_END)
            self:closeAll()
        end
        -- 刷新icon
        self:removeActButton()
    end
end

function PromoteLowMgr:removeActButton()
    ActivityEventCenter:dispatch(ActivityEvent.REMOVE_ACTIVITY,{actId = PromoteLowConst.ACT_ID})
end

-- 打开主界面
function PromoteLowMgr:showMainView(delegate)
    delegate = delegate or {}
    local function showMainPanel()
        local MainPanelVM = require "amf.feature.localactivity.promotelow.view.MainPanelVM"
        local vm = MainPanelVM:create(delegate)
        vm:popout()
        self:addVmToMgr(vm)
    end
    showMainPanel()
    self:cancelNewActState()
end

function PromoteLowMgr:getVersionStr()
    return self:getValue("activityRound").."_"..self:getValue("round")
end

function PromoteLowMgr:cancelNewActState()
    local icon = self._iconManager:getIconByIconKey(tostring(PromoteLowConst.ACT_ID))
    if icon then
        icon:cancelNewActState()
    end
end

-- 是否可以强弹场景3/4
function PromoteLowMgr:canAutoPopSignPanel()
    local enable = self:isEnabled()
    self:log("PromoteLowMgr: 开始检查强弹", enable, self:isModelEnabled())
    if not enable then return false end
    if not self:isModelEnabled() then return false end
    local rewarded = self:getValue("rewarded")
    -- 判断是否已经领奖了
    if rewarded then
        self:log("PromoteLowMgr: 已经领奖了 不弹")
        return false
    end
    local curDayNum = TimeUtil:getDayIdxSince1970()
    -- 配置成了一天弹一次，就不用自己存了， config那边突然不会计数了
    if self:getLocalValue("autoPopPanel_"..curDayNum) then
        self:log("PromoteLowMgr: 已经弹过了 不弹")
        return false
    end
    -- 如果可以领奖，但是没网就不弹了
    if self:isCanReward() then
        if not self._networkStatusManager:isNetworkEnabled() then
            self:log("PromoteLowMgr: 可以领奖没网 不弹")
            return false
        end
    elseif not self:isTodaySigned() then
        self:log("PromoteLowMgr: 没盖章 不弹")
        return false
    end
    return true
end

-- 记录今天弹过了
function PromoteLowMgr:setAutoPopSignPanel()
    local curDayNum = TimeUtil:getDayIdxSince1970()
    self:setLocalValue("autoPopPanel_"..curDayNum, true)
end

-- 今天是否盖章了
function PromoteLowMgr:isTodaySigned()
    local todayNum = TimeUtil:getDayIdxSince1970()
    local dayList = self:getValue("dayList") or {}
    return table.exist(dayList, todayNum)
end

-- 是否有奖励可领
function PromoteLowMgr:hasRewards()
    if not self:isEnabled() then return false end
    return self:isCanReward()
end

function PromoteLowMgr:dc(category, subCategory, extraData)
    local params = {
        category = category,
        sub_category = subCategory,
    }

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end
    -- self:log("dc ----", tts(params))
    DcUtil:UserTrack(params)
end

function PromoteLowMgr:log(...)
    if EnvUtil:isDevelopMode() then
        printx(27, "PromoteLowMgrLog:" , ...)
    end
end

function PromoteLowMgr:addBuffEndTime(timeInMillis)
    local buffEndTime = tonumber(self:getValue("scoreBuffExpireTime")) or 0
    local curTime = TimeKit:timeInMillis()
    if buffEndTime <= curTime then
        buffEndTime = curTime
    end
    buffEndTime = buffEndTime + timeInMillis
    self:setValue("scoreBuffExpireTime", buffEndTime)
end

-- buff结束时间
function PromoteLowMgr:getBuffEndTime()
    if not self:isActEnabled() then return end
    local buffEndTime = self:getValue("scoreBuffExpireTime") or 0
    -- 要返回毫级时间戳
    return tonumber(buffEndTime)
end

--获取分数BUFF加成值跟buff结束时间,因为是限时buff，活动结束了依然会走
function PromoteLowMgr:getCurAvailableBuffAndEndTime()
    local scoreBuffRate = self._propManager:getScoreBuffRate(PromoteLowConst.StarBuff_ID)
    local buffEndTime = self:getBuffEndTime() or 0
    return scoreBuffRate, buffEndTime
end

--分数buff
function PromoteLowMgr:onActUBFAddScoreBuff(event)
    local eventData = event:getData()
    if eventData.isAskForHelp then return false end
    local scoreBuffRate, buffEndTime = self:getCurAvailableBuffAndEndTime()
    local hasScoreBuff = buffEndTime > TimeKit:timeInMillis()
    if hasScoreBuff then
        local builder = UBFPlayImproveBuffBuilder:create()
        builder:setModSourceId(PromoteLowConst.ACT_ID)
        builder:addBuffWithOld(InitBuffType.CUSTOM_SCORE_BUFF, InitBuffCreateType.BUFF_ACTIVITY, scoreBuffRate - 1)
        table.insert(eventData.buffList, builder:toBuffCreateData() )
    end
end

--开始面板挂牌分数buff显示
function PromoteLowMgr:onActScoreBuffLevelStartPanel(event)
    local eventData = event:getData()
    if eventData.isAskForHelp then return false end
    local scoreBuffRate, buffEndTime = self:getCurAvailableBuffAndEndTime()
    local hasScoreBuff = buffEndTime > TimeKit:timeInMillis()
    if hasScoreBuff then
        local buffData = {buffExtraRate = scoreBuffRate - 1, buffEndTime = buffEndTime, actId = PromoteLowConst.ACT_ID}
        table.insert(eventData.scoreBuffDataList, buffData)
    end
end

---------------------------------- CUSTOM_GAIN ----------------------------------

function PromoteLowMgr:_onCustomGain(event)
    local reward = event:getData()
    if reward.itemId == PromoteLowConst.StarBuff_ID then
        self:addBuffEndTime(60 * reward.num * 1000)
    end
end

return PromoteLowMgr