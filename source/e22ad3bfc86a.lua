local deferred = require "amf.script.sugar.deferred"
local MarkConst = require "amf.feature.dailyreward.mark.config.MarkConst"

local MarkEventCenter = require "amf.feature.dailyreward.mark.event.MarkEventCenter"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local FeedContext = require "amf.middleware.feed.FeedContext"
local FeedRevisitConfig = require "amf.feature.minihub.recommendationfeed.FeedRevisitConfig"
require "amf.middleware.prop.event.PropEvent"
require "amf.feature.dailyreward.mark.extend.act.MarkPreOpenContext"
require "amf.feature.dailyreward.mark.extend.act.ActFestivalConst"
local MarkManager = class("MarkManager")

local _curYear = nil
local _curMonth = nil
local _curDay = nil
local privateNS = {}

function MarkManager:ctor()
    self._todayIsMark = false
    self._userManager = nil
    self._optionalDataManager = nil
    self._popoutManager = nil
    self._iconManager = nil
    self._autoPopupMgr = nil
    self._profileManager = nil
    self._actScoreBuffMgr = nil
    self._propManager = nil
    self._networkStatusManager = nil
    self._customGainRegistered = false
end

function MarkManager:setNetworkStatusManager(mgr)
    self._networkStatusManager = mgr
end

function MarkManager:setPropManager(mgr)
    self._propManager = mgr
end

function MarkManager:setActScoreBuffMgr(actScoreBuffMgr)
    self._actScoreBuffMgr = actScoreBuffMgr
end

function MarkManager:setProfileManager(profileManager)
    self._profileManager = profileManager
end

function MarkManager:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
end

function MarkManager:setPopoutManager(popoutManager)
    self._popoutManager = popoutManager
end

function MarkManager:setOptionalDataManager(optionalDataManager)
    self._optionalDataManager = optionalDataManager
end

function MarkManager:setUserManager(userManager)
    self._userManager = userManager
end

function MarkManager:setIconManager(iconManager)
    self._iconManager = iconManager
end

function MarkManager:initialize()
    privateNS.markModel = require("amf.feature.dailyreward.mark.model.MarkModel"):create()
    self._todayIsMark = self._optionalDataManager:getTempOptionalDataValue("todayIsMark")
    self:resetTime()
    MarkEventCenter:registerFeature(self)
    MarkEventCenter:registerSystem(self)
    -- 先初始化一次
    self._lastEnabled = self:isEnabled()
    self:registerProp()
    self:registerCustomGainEvent()

end

function MarkManager:registerCustomGainEvent()
    if self._customGainRegistered then return end
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
    self._customGainRegistered = true
end

function MarkManager:registerProp()
    require "amf.feature.dailyreward.mark.prop.AMFProp_56019"
end

function MarkManager:onActUserSyncEnd(event)
    local data = event:getData()
    if data and data.isReconnect then
        self._todayIsMark = self._optionalDataManager:getTempOptionalDataValue("todayIsMark")
    end
end

function MarkManager:onActEnterStage2(evt)
    if not self:isEnabled() then return end
    local data = evt:getData()
    if not data or not data.isFirstEnter then return end
    if self:isTodayMarked() then return end
    if FeedContext.isFeedEnterUser()
        and FeedContext.getSceneStr() == FeedContext.SceneType.IMPORTANT_EVENT_DROP
        and FeedRevisitConfig.isImportantEventSignIn(FeedContext.getTrialSourceIdFromJS()) then
        return
    end
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.MARK)
    end
    local function creator()
        self:showMainPanel({
            closeCallback = onHandleOver,
            dcLocation = 1,
            isClick = false
        })
    end
    self._autoPopupMgr:addPopupConfig(PopupCheckPoint.MARK, creator)
end

-- 到后台
function MarkManager:onSystemEnterBackground()
    if not EnvUtil:isApp() then return end
    local LocalPush = require "amf.feature.dailyreward.mark.push.LocalPush"
    LocalPush:removeLocalPush()
    if not self:isEnabled() then return end
    LocalPush:checkLocalPush29()
    LocalPush:checkLocalPush23()
end

function MarkManager:onActPlayLevelEnd(evt)
    local data = evt:getData()
    if not data.isWin then return end
    local curEnable = self:isEnabled()
    if self._lastEnabled ~= curEnable and curEnable == true then
        self:initialize()
    end
end

function MarkManager:getCurDay()
    return _curDay
end

function MarkManager:getCurMonth()
    return _curMonth
end

function MarkManager:getCurYear()
    return _curYear
end

function MarkManager:resetTime()
    local timeData = os.date2(TimeKit:timeInSec())
	_curYear = timeData.year
	_curMonth = timeData.month
	_curDay = timeData.day
end

function MarkManager:isEnabled()
    local Group = require "amf.feature.dailyreward.mark.Group"
    if Group:isOff() then return false end
    local userTopLevel = self._userManager:getTopLevelId()
    local showLevel = 201
    if userTopLevel < showLevel then return false end
    return true
end

function MarkManager:isDataEnabled()
    local isDataOk = privateNS.markModel:isDataEnabled()
    local lastReqOk = self:getLastReqYM() == self:getMarkValue("reqYearAndMonth")
    local hasTextCache = self:getMarkValue("markBannerText")
    -- self:log("isDataEnabled ----", isDataOk, lastReqOk, self:getLastReqYM(), self:getMarkValue("reqYearAndMonth"))
    return isDataOk and lastReqOk and hasTextCache
end

function MarkManager:_checkCanPop(isClick)
    local scene = Director:sharedDirector():getRunningSceneLua()
	if not scene then return false end

	if not scene:isScene("MainScene") then return false end

    -- 有界面不弹
    local has, popoutList = self._popoutManager:haveWindowOnScreenWithoutCommonTip(isClick)
    if has then return false end
    return true
end

function MarkManager:updateMarkButton()
    local markIcon = self._iconManager:getIconByIconKey(IconKey.kMark)
    if markIcon then
        markIcon:updateState()
    end
end

function MarkManager:setMarkActContext(context)
    self._markActContext = context
end
function MarkManager:getMarkActContext()
    return self._markActContext
end

-- 展示主界面
function MarkManager:showMainPanel(param)
    if not self:isEnabled() then return end
    local dcLocation = param.dcLocation or -1
    local isClick = param.isClick
    local closeCallback = param.closeCallback
    local skipIfTodayMarked = param.skipIfTodayMarked == true
    local forceRequest = param.forceRequest == true

    self.dcLocation = dcLocation
    -- 没网
    if not self._networkStatusManager:isNetworkEnabled() then
        CommonTip:showTip("网络异常，请检查网络设置~")
        safeRunCall(closeCallback)
        return
    end
    -- 点击签到icon，但有界面弹出，不弹
    if isClick and not self:_checkCanPop(isClick) then
        safeRunCall(closeCallback)
        return
    end

    local function _showMainPanel(delegate)
        if skipIfTodayMarked and self:isTodayMarked() then
            safeRunCall(closeCallback)
            return
        end
        if not self:_checkCanPop() then
            safeRunCall(closeCallback)
            return
        end
        local function closeCall()
            -- 刷新签到上的红点
            self:updateMarkButton()
            self.mainPanelVM = nil
            safeRunCall(closeCallback)

            -- if EnvUtil:isOhos() then
            --     local OhosCard = require "ohos_card"
            --     if OhosCard then
            --         OhosCard:flush()
            --     end
            -- end
        end

        delegate.closeCallback = closeCall
        delegate.autoCloseAfterSignIn = param.autoCloseAfterSignIn == true
        delegate.signInRequest = param.signInRequest
        delegate.panelShownCallback = param.panelShownCallback
        local MarkMainPanelVM = require_debug "amf.feature.dailyreward.mark.view.main.MarkMainPanelVM"
        self.mainPanelVM = MarkMainPanelVM:create(delegate)
        self.mainPanelVM:setLoadResFailCallback(closeCallback)
        self.mainPanelVM:popout(nil, not EnvUtil:isMiniGame())

        -- 打点
        self:dc("signPanel_popUp")
        self:dc("newPanel_trigger",{
                t1=tostring(self:getMarkValue("totalMark")),
                t2=tostring(self:getMonthSignCount()),
                t3=tostring(self:getCurMonth()),
            })
    end
    local function _reqThenOpen()
        -- self:log("签到界面 请求后打开")
        self:requestMainInfo():next(function(data)
            local context = self:initMarkActContext()
            if context and context:getPreOpenFunc() then
                context:getPreOpenFunc()(function()
                    -- 再判断一次，因为有可能失败了
                    if not context:isEnabled() then
                        self:setMarkActContext(nil)
                    end
                end)
            end
            _showMainPanel({
                dcLocation = dcLocation,
                isClick = isClick,
                closeCallback = closeCallback
            })
        end, function(isCancel)
            safeRunCall(closeCallback)
        end)
    end
    local function _reqAndOpen()
        -- self:log("签到界面 直接打开")
        self:requestMainInfo()
        _showMainPanel({
            dcLocation = dcLocation,
            isClick = isClick,
            closeCallback = closeCallback,
            useLocalData = true
        })
    end
    -- 如果是点击icon，一定先请求数据
    if isClick or forceRequest then
        -- self:log("点击icon")
        _reqThenOpen()
    else
        -- 如果数据可用就
        if self:isDataEnabled() then
            -- self:log("数据可用")
            _reqAndOpen()
        else
            -- self:log("数据不可用")
            _reqThenOpen()
        end
    end
end

function MarkManager:initMarkActContext()
    self:setMarkActContext(nil)
    local preOpenContextList = {}
    MarkEventCenter:dispatch(MarkEvent.MARK_PREOPEN_CHECK, preOpenContextList)
    table.sort(preOpenContextList, function(a, b)
        return a:getPriority() < b:getPriority()
    end)
    local context = preOpenContextList[1]
    self:setMarkActContext(context)
    return context
end

-- 跨天
function MarkManager:onActPassDay()
    if not self:isEnabled() then return end
    self._todayIsMark = false
    self:resetTime()
    MarkEventCenter:dispatch(MarkEvent.MARK_PASSDAY)
    if self.mainPanelVM then
        self.mainPanelVM:doPassDayRefresh()
    else
        self:handleAutoPopout(true)
    end
end

function MarkManager:isTodayMarked()
    return self._todayIsMark
end

-- 强弹
function MarkManager:handleAutoPopout(fromPassDay)
    if not self:isEnabled() then return end
    -- 今天签到了不弹
    if self:isTodayMarked() then return end

    local function doMarkAutoPopup()
        self:onActEnterStage2(AMFEvent.new("", {
            isFirstEnter = true
        }))
    end
    if fromPassDay then
        local delay = math.random(60)
        setTimeOut(doMarkAutoPopup, delay)
    else
        doMarkAutoPopup()
    end
end

function MarkManager:getMarkValue(keyChain)
    return privateNS.markModel:getValue(keyChain)
end

function MarkManager:setMarkValue(keyChain, value, flush)
    return privateNS.markModel:setValue(keyChain, value, flush)
end

-- 根据day获得签到信息
function MarkManager:getDataByDay(day)
    local dayStatusList = privateNS.markModel:getValue("dayStatusList") or {}
    for _,v in ipairs(dayStatusList) do
        if v and v.day == day then
            return v
        end
    end
    return nil
end

-- 获得第一个漏签的日期data
function MarkManager:getFirstMissionDayData()
    local dayStatusList = privateNS.markModel:getValue("dayStatusList") or {}
	for _,v in ipairs(dayStatusList) do
		if v and v.markType == MarkConst.MarkType.NONE and v.day < _curDay then
			return v
		end
	end
	return nil
end

function MarkManager:isMonthFullSign()
    local dayStatusList = privateNS.markModel:getValue("dayStatusList") or {}
    for _,v in ipairs(dayStatusList) do
        if v and v.markType == MarkConst.MarkType.NONE then
            return false
        end
    end
    return true
end

-- 签到了几天
function MarkManager:getMonthSignCount()
    --  * 签到类型， 0 未签到， 1：正常签到  2：人民币补签  5：v2兼容v1的自动补全签到
    local count = 0
    local dayStatusList = privateNS.markModel:getValue("dayStatusList") or {}
    for _,v in ipairs(dayStatusList) do
        if v and v.day <= self:getCurDay() and v.markType > MarkConst.MarkType.NONE then
            count = count + 1
        end
    end
    return count
end

-- 漏签天数
function MarkManager:getMonthMissionCount()
    local count = 0
    local dayStatusList = privateNS.markModel:getValue("dayStatusList") or {}
	for _,v in ipairs(dayStatusList) do
		if v and v.markType == MarkConst.MarkType.NONE and v.day < _curDay then
			count = count + 1
		end
	end
	return count
end

function MarkManager:requestFullShareReward(param)
    param = param or {}
    param.year = self:getCurYear()
    param.month = self:getCurMonth()

    local d = deferred.new()
    privateNS.markModel:requestFullShareReward(param):next(function(response)
        local data = response:getData()
        local rewardList = data.rewardBeanList or {}
        if not table.isEmpty(rewardList) then
            -- 打点
            GainPropData:create()
                :setFeature(DcFeatureType.kSignIn)
                :setSource("sign_2020_share_sendout")
                :setProps(rewardList)
                :execute()
        end
        -- 修改已经领取过
        self:setMarkValue("isFullShareRewarded", true)
        d:resolve(rewardList)
    end, function(response)
        CommonTip:showErrorTip(response)
        d:reject(response:isCancel())
    end)
    return d
end

function MarkManager:requestTotalShareReward(param)
    param = param or {}
    param.year = self:getCurYear()
    param.month = self:getCurMonth()

    local d = deferred.new()
    privateNS.markModel:requestTotalShareReward(param):next(function(response)
        local data = response:getData()
        local rewardList = data.rewardBeanList or {}
        if not table.isEmpty(rewardList) then
            -- 打点
            GainPropData:create()
                :setFeature(DcFeatureType.kSignIn)
                :setSource("sign_2020_share_total")
                :setProps(rewardList)
                :execute()
        end
        -- 修改已经领取过
        self:setMarkValue("isTotalShareRewarded", true)
        d:resolve(rewardList)
    end, function(response)
        CommonTip:showErrorTip(response)
        d:reject(response:isCancel())
    end)
    return d
end

function MarkManager:getLastReqYM()
    local str = ""..self:getCurYear().."_"..self:getCurMonth()
    return str
end

-- 主info
function MarkManager:requestMainInfo()
    local d = deferred.new()
    privateNS.markModel:requestMainInfo({
        protocolVersion = MarkConst.ProtocolVersion,
    }):next(function(response)
        self._todayIsMark = self:getDayMarked(self:getCurDay())
        -- 记录上次请求时间
        self:setMarkValue("reqYearAndMonth", self:getLastReqYM())
        self:setMarkValue("isHttpError", false)
        d:resolve(response:getData())
    end, function(response)
        CommonTip:showErrorTip(response)
        d:reject(response:isCancel())
    end)
    return d
end

-- 补单
function MarkManager:requestConsumeRmbChances()
    local d = deferred.new()
    self:setMarkValue("isHttpError", true)
    privateNS.markModel:requestRmbChances():next(function(response)
        local data = response:getData()
        local lastDayList = privateNS.markModel:getValue("dayStatusList") or {}
        privateNS.markModel:onResponseMarkV3GetInfo(response, nil, true)
        local dayList = privateNS.markModel:getValue("dayStatusList") or {}
        -- 找到补单的那天
        local needDay
        for _,v in ipairs(dayList) do
            local find = false
            for _,vv in ipairs(lastDayList) do
                if v.day == vv.day and v.markType ~= MarkConst.MarkType.NONE and vv.markType == MarkConst.MarkType.NONE then
                    needDay = v.day
                    find = true
                    break
                end
            end
            if find then
                break
            end
        end
        -- 打点
        local count = data.rewards and #data.rewards
        self:dc("resign_resubmit",{t1 = count,t2 = privateNS.markModel:getValue("v3MakeUpChances")})

        -- 丢单数量清零
        -- 协议里已经发了
        -- privateNS.markModel:setValue("v3MakeUpChances", 0)
        self:_checkOtherRewards(data, true, true)
        d:resolve({
            data = data,
            needDay = needDay
        })

        MarkEventCenter:dispatch(MarkEvent.MARK_MARKUP_SUCCESS, {
            day = needDay,
            hasMonthRewards = not table.isEmpty(data.monthRewards or {}),
            from = MarkConst.MarkFromType.COMPENSATION,
        })
        self:setMarkValue("isHttpError", false)
    end, function(response)
        CommonTip:showErrorTip(response)
        d:reject(response:isCancel())
    end)
    return d
end

-- 签到
function MarkManager:requestSignIn(param)
    local d = deferred.new()
    self:setMarkValue("isHttpError", true)
    -- 测试失败后强弹会不会重新请求
    -- do return d:reject(false) end
    privateNS.markModel:requestSignIn(param):next(function(response)
        local data = response:getData()
        -- 增加签到天数
        self:_addTotalMark()
        -- 设置今天签到了
        local day = param.day
        self:_setDayMarkState(day, MarkConst.MarkType.SIGN)
        self._todayIsMark = true

        self:_checkOtherRewards(data)

        self:dc("sign_days",{
            dateTime = param.dateTime,
            t1=tostring(self:getMarkValue("totalMark")),
            t2=tostring(self:getMonthSignCount()),
            t3=tostring(self:getCurMonth()),
        })
        self:setMarkValue("isHttpError", false)
        -- 签到成功
        _G.amfEC:notifyFeature(FeatureEvent.MARK_SIGN)
        d:resolve(data)

        MarkEventCenter:dispatch(MarkEvent.MARK_MARKUP_SUCCESS, {
            day = day,
            hasMonthRewards = not table.isEmpty(data.monthRewards or {}),
            from = MarkConst.MarkFromType.NORMAL,
        })
    end, function(response)
        if response:isCancel() then
            self:setMarkValue("isHttpError", false)
        end
        CommonTip:showErrorTip(response)
        d:reject(response:isCancel())
    end)
    return d
end

function MarkManager:initMakeupPayTracer(goodsId)
    local PaymentTracer = require 'amf.middleware.purchase.dc.trace.PaymentTracer'
    self._makeupPayTracer = PaymentTracer.createRMBPayTracer(
        DcFeatureType.kSignIn,
        DcSourceType.kSign2020MakeUp,
        goodsId,
        DCPayProgressPayPanelShowType.kUserClick
    )
end

function MarkManager:doTracer(funcName)
    if self._makeupPayTracer then
        self._makeupPayTracer[funcName](self._makeupPayTracer)
    end
end

-- 补签
function MarkManager:requestMakeUp(param)
    local day = param.day
    local goodsId = param.goodsId
    local clickBtn = param.clickBtn
    local d = deferred.new()
    -- 补签时间戳
    local date = {
    	year = _curYear,
    	month = _curMonth,
    	day = day
    }
    local time = os.time2(date)*1000
    -- 补签前检查
    self:_requestPreMakeUp(time):next(function()
        -- 付费
        self:_requestBuy(goodsId):next(function()
            self:_requestMakeup(time):next(function(response)
                local data = response:getData()
                self:_addTotalMark()
                self:_setDayMarkState(day, MarkConst.MarkType.MAKEUP_MONEY)
                self:_checkOtherRewards(data, true)
                self:dc("resign",{
                    dateTime = time,
                    t1 = 1,
                    t2 = tostring(privateNS.markModel:getDayCountByMarkType(MarkConst.MarkType.MAKEUP_MONEY)),
                    t3 = clickBtn and 1 or 2,
                    t4 = time,
                    t5 = data.rewards and data.rewards[1].itemId
                })
                d:resolve(data)

                MarkEventCenter:dispatch(MarkEvent.MARK_MARKUP_SUCCESS, {
                    day = day,
                    hasMonthRewards = not table.isEmpty(data.monthRewards or {}),
                    from = MarkConst.MarkFromType.CASH,
                })
            end, function(errCode, isCancel)
                CommonTip:showErrorTip(errCode)
                d:reject(isCancel)
            end)
        end, function(errCode, isCancel)
            -- CommonTip:showErrorTip(errCode)
            d:reject(isCancel)
        end)
    end, function(errCode, isCancel)
        CommonTip:showErrorTip(errCode)
        d:reject(isCancel)
    end)
    return d
end

function MarkManager:_setDayMarkState(day, markType)
    privateNS.markModel:setDayMarkState(day, markType)
end

function MarkManager:getDayMarked(day)
    local markType = self:getDayMarkState(day)
    return markType ~= MarkConst.MarkType.NONE and day <= _curDay
end

function MarkManager:getDayMarkState(day)
    return privateNS.markModel:getDayMarkState(day)
end

-- 需要补签用人民币的的天数
function MarkManager:getMoneyMakeUpDays()
    local count = 0
    local dayStatusList = self:getMarkValue("dayStatusList") or {}
    for _,v in ipairs(dayStatusList) do
        if v and v.markType == MarkConst.MarkType.MAKEUP_MONEY then
            count = count + 1
        end
    end
    return count
end

function MarkManager:_addTotalMark(value)
    value = value or 1
    local totalMark = self:getMarkValue("totalMark") or 0
    privateNS.markModel:setValue("totalMark", totalMark + value)
end

function MarkManager:_requestPreMakeUp(time)
    local d = deferred.new()
    self:setMarkValue("isHttpError", true)
    -- 测试失败后强弹会不会重新请求
    -- do return d:reject(0) end
    privateNS.markModel:requestPreMakeUp({dateTime = time}):next(function(response)
        self:setMarkValue("isHttpError", false)
        d:resolve()
    end, function(response)
        if response:isCancel() then
            self:setMarkValue("isHttpError", false)
        end
        d:reject(response:getErrorCode(), response:isCancel())
    end)
    return d
end

function MarkManager:_requestMakeup(time)
    local d = deferred.new()
    self:setMarkValue("isHttpError", true)
    -- 开始补签
    privateNS.markModel:requestMakeUp({
        dateTime = time,
        payType = 0  -- 只有人民币补签
    }):next(function(response)
        self:setMarkValue("isHttpError", false)
        d:resolve(response)
    end, function(response)
        d:reject(response:getErrorCode(), response:isCancel())
    end)
     return d
end

function MarkManager:_requestBuy(goodsId)
    local d = deferred.new()
    self:setMarkValue("isHttpError", true)
    local function onSuccess()
        self:doTracer("paySuccess")
        self:setMarkValue("isHttpError", false)
        setTimeOut(function()
            d:resolve()
        end, 1)
    end
    local function onFail(errorCode, errorMsg, payInfo)
        self:doTracer("payFail")
        d:reject(errorCode)
    end
    local function onCancel(payInfo)
        self:setMarkValue("isHttpError", false)
        self:doTracer("payCancel")
        d:reject(nil, true)
    end
    -- 开始购买
    local buyContext = BuyContext.new(goodsId, MoneyType.kRmb)
        :setFeatureAndSource(DcFeatureType.kSignIn, DcSourceType.kSign2020MakeUp)
        :setCallback(onSuccess, onFail, onCancel)
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
    return d
end

-- 28天签到奖励、累签奖励、普通奖励
function MarkManager:_checkOtherRewards(data, isMakeup, isLost)
    if not table.isEmpty(data.rewards) then
        GainPropData:create()
            :setFeature(DcFeatureType.kSignIn)
            :setSource(isMakeup and DcSourceType.kSign2020MakeUp or DcSourceType.kSign2020SignIn)
            :setProps(data.rewards)
            :execute()
    end
    if not table.isEmpty(data.monthRewards) then
        GainPropData:create()
            :setFeature(DcFeatureType.kSignIn)
            :setSource(DcSourceType.kSign2020MonthReward)
            :setProps(data.monthRewards)
            :execute()
    end
    if not table.isEmpty(data.totalRewards) then
        GainPropData:create()
            :setFeature(DcFeatureType.kSignIn)
            :setSource(DcSourceType.kSign2020TotalReward)
            :setProps(data.totalRewards)
            :execute()
    end

    -- 月签到28天奖励
	if data.monthRewards then
        privateNS.markModel:setValue("monthRewardState", 1)
		self:dc("reward_box")
	end
	-- 累签奖励
	if data.totalRewards then
        local totalMarkRewardStep = privateNS.markModel:getValue("totalMarkRewardStep")
        -- markV3ConsumeRmbChances已经把totalMarkRewardStep 加1了，这里不用加了, 其他时候用加
        if not isLost then
		    privateNS.markModel:setValue("totalMarkRewardStep", totalMarkRewardStep + 1)
        end
		self:dc("reward_historyBox",{t1 =tostring(totalMarkRewardStep + 1)})
	end
	-- 额外的奖励数据
	if data.specialMarkInfos then
		-- 通知活动额外奖励 TODO
		-- MarkManager:notifyAct(MarkMeta.Event.kHandleExtReward, {data = data.specialMarkInfos})
	end
end

function MarkManager:addBuffEndTime(addTime)
    self._actScoreBuffMgr:addScoreBuffEndTime("addScoreBuff10", addTime)
end

-- 获得buff的结束时间
function MarkManager:getBuffEndTime()
    local buffEndTime = self._actScoreBuffMgr:getScoreBuffEndTime("addScoreBuff10") or 0
    return tonumber(buffEndTime)/1000
end

--获取分数BUFF加成值跟buff结束时间,因为是限时buff，活动结束了依然会走
function MarkManager:getCurAvailableBuffAndEndTime()
    local scoreBuffRate = self._propManager:getScoreBuffRate(MarkConst.BUFF_ID)
    local buffEndTime = self:getBuffEndTime() or 0
    return scoreBuffRate, buffEndTime
end

--分数buff
function MarkManager:onActUBFAddScoreBuff(event)
    local eventData = event:getData()
    if eventData.isAskForHelp then return false end
    local scoreBuffRate, buffEndTime = self:getCurAvailableBuffAndEndTime()
    local hasScoreBuff = buffEndTime > TimeKit:timeInSec()

    local levelId = eventData.levelId
    local levelScene = eventData.levelScene

    local levelSupportType = UBFActHelper:getPlayLevelModeType(levelId, nil, levelScene)
    local levelOk = levelSupportType == LevelSupportModeType.kNormal or levelSupportType == LevelSupportModeType.kExceedStar or levelSupportType == LevelSupportModeType.kExceedScore

    if not levelOk then return end

    if hasScoreBuff then
        local builder = UBFPlayImproveBuffBuilder:create()
        builder:setModSourceId(MarkConst.ACT_ID)
        builder:addBuffWithOld(InitBuffType.CUSTOM_SCORE_BUFF, InitBuffCreateType.BUFF_ACTIVITY, scoreBuffRate - 1)
        table.insert(eventData.buffList, builder:toBuffCreateData() )
    end
end

--开始面板挂牌分数buff显示
function MarkManager:onActScoreBuffLevelStartPanel(event)
    local eventData = event:getData()
    if eventData.isAskForHelp then return false end
    local scoreBuffRate, buffEndTime = self:getCurAvailableBuffAndEndTime()
    local hasScoreBuff = buffEndTime > TimeKit:timeInSec()

    local levelId = eventData.levelId
    local levelScene = eventData.levelScene

    local levelSupportType = UBFActHelper:getPlayLevelModeType(levelId, nil, levelScene)
    local levelOk = levelSupportType == LevelSupportModeType.kNormal or levelSupportType == LevelSupportModeType.kExceedStar or levelSupportType == LevelSupportModeType.kExceedScore

    if not levelOk then return end


    if hasScoreBuff then
        local buffData = {buffExtraRate = scoreBuffRate - 1, buffEndTime = buffEndTime, actId = MarkConst.ACT_ID}
        table.insert(eventData.scoreBuffDataList, buffData)
    end
end

function MarkManager:dc( sub_category, params )
    params = params or {}
    params.game_type = "stage"
    params.game_name = params.game_name or "sign_in_2020"
    params.category = params.category or "sign_in_2020"
    params.sub_category = sub_category

    params.dcLocation = self.dcLocation
    params.t = self.dcLocation == 1 and 0 or 1
    DcUtil:dcForUserTrack(params)
end

function MarkManager:log(...)
    if EnvUtil:isDevelopMode() then
        -- printx(27, "MarkManager: ", ...)
        -- UError("MarkManager: ", ...)
    end
end

---------------------------------- CUSTOM_GAIN ----------------------------------

function MarkManager:_onCustomGain(event)
    local reward = event:getData()
    if reward.itemId == MarkConst.BUFF_ID then
        self:addBuffEndTime((reward.num or 1) * 60 * 1000)
    end
end

return MarkManager
