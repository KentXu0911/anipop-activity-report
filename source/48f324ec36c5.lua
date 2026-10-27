local MainPanelVM = class("PromoteLowMainPanelVM", AMFBasePanelVM)
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local deferred = require "amf.script.sugar.deferred"
local Res = require "amf.feature.localactivity.promotelow.config.Res"
local PromoteLowEventCenter = require "amf.feature.localactivity.promotelow.event.PromoteLowEventCenter"

function MainPanelVM:_createPanel(...)
    local MainPanel = require_debug "amf.feature.localactivity.promotelow.view.MainPanel"
    local panel = MainPanel:create(MainPanelVM, ...)
    return panel
end

function MainPanelVM:init(delegate)
    self._userStateMgr = _G.amfBean("UserStateManager")
    self:setCloseCallback(delegate.closeCallback)
    self.userClick = delegate.userClick
    self._mgr = _G.amfBean("PromoteLowMgr")
    self.showJiCount = self._mgr:getValue("totalDays")
    self:updateData()
    local todayNum = TimeUtil:getDayIdxSince1970()
    -- print("self.todaySigned ----", self.todaySigned, self._mgr:getLocalValue("popCardSigned_anim_"..todayNum), self.userClick)
    if self.todaySigned and not self._mgr:getLocalValue("popCardSigned_anim_"..todayNum) 
        and not self.userClick 
        then
        self.needPlayDayNum = todayNum
    end
    self.dayList = table.clone(self._mgr:getValue("dayList") or {})
    self.signedListCount = table.count(self.dayList)
    if self.needPlayDayNum then
        self.signedListCount = self.signedListCount - 1
    end
    self.userState = self._userStateMgr:getUserSegmentState()
    self.panelId = UICreateUtil:getPanelId("PromoteMainPanel")
    self.rewardList = self._mgr:getValue("rewardList") or {}
    

    local versionStr = self._mgr:getValue("activityRound").."_"..self._mgr:getValue("round")
    self.versionStr = versionStr
    self._mgr:dc("low_active", "main_panel_show", {
		panel_id = self.panelId,
		t1 = self.userClick and 1 or 2,
		t2 = table.count(self.dayList),
		t3 = self.versionStr,
		t4 = 1,
		t5 = self._mgr:getValue("activityConfigVersion") or 0,
        t6 = self._mgr:getValue("rewardGroupId"),
	})
    self:registerEvent()
end

function MainPanelVM:registerEvent()
    PromoteLowEventCenter:register(PromoteLowEvent.PASS_DAY, self.onPassDay, self)
end

function MainPanelVM:unregisterEvent()
    PromoteLowEventCenter:unregister(PromoteLowEvent.PASS_DAY, self.onPassDay)
end

function MainPanelVM:onPassDay()
    self:updateData()
    self:updateView()
end

function MainPanelVM:updateData()
    self.todaySigned = self._mgr:isTodaySigned()
    self.rewarded = self._mgr:getValue("rewarded")
end

function MainPanelVM:reuse(...)
    AMFBasePanelVM.reuse(self, ...)
end

function MainPanelVM:firstLoadCompleted()
    self:callViewFunc("initData")
    self:callViewFunc("initUI")
    self:callViewFunc("initRewardPart", self.rewardList, self.rewarded)
    self:callViewFunc("initTopDesc", self.userState)
    self:callViewFunc("initBoxPart")
    self:callViewFunc("initSignPart", self.showJiCount, self.signedListCount)
    self:callViewFunc("initButton")

    self:updateView()

    self._timerId = TimerUtil.addAlarm(function()
        if not self.lastUpdateTime then
            self.lastUpdateTime = TimeKit:timeInSec()
        end
        -- 1.5s 一次box动画
        if TimeKit:timeInSec() - self.lastUpdateTime > 1.5 then
            self.lastUpdateTime = TimeKit:timeInSec()
            self:callViewFunc("updateBoxState", nil, nil, self.rewarded, self._mgr:isCanReward())
        end

        self:_updateHelpPanel()
    end, 1, 0)
end

function MainPanelVM:secondLoadCompleted()

end

function MainPanelVM:onEnterPanelRun()
    local isCanReward = self._mgr:isCanReward()
    if isCanReward then
        self:lock()
    end
    deferred.success()
    :next(function()
        if self.isDisposed then return end
        local td = deferred.new()
        TimerUtil.addAlarm(function()
            if self.isDisposed then return end
            td:resolve()
        end, 0.3)
        return td
    end)
    :next(function()
        if self.isDisposed then return end
        local td = deferred.new()
        if self.needPlayDayNum then
            self._mgr:setLocalValue("popCardSigned_anim_"..self.needPlayDayNum, true)
            self:callViewFuncWithCallback("playSignAnim", function()
                td:resolve()
            end, self.signedListCount, isCanReward)
            self.needPlayDayNum = nil
        else
            td:resolve()
        end
        return td
    end)
    :next(function()
        if self.isDisposed then return end
        local td = deferred.new()
        if isCanReward then
            self:callViewFuncWithCallback("playBoxActiveEff", function()
                td:resolve()
            end)
        else
            td:resolve()
        end
        return td
    end)
    :next(function()
        if self.isDisposed then return end
        local td = deferred.new()
        if isCanReward then
            self:onGetRewardFlow(function()
                td:resolve()
            end)
        else
            td:resolve()
        end
        return td
    end)
    :next(function()
        if self.isDisposed then return end
        self:updateView()
        if not self.userClick then
		    self:callViewFunc("addJumpLayer")
        end
        self:unlock()
    end)
end

function MainPanelVM:recycle()
    if self._timerId then
        TimerUtil.removeAlarm(self._timerId)
        self._timerId = nil
    end
    AMFBasePanelVM.recycle(self)
end

function MainPanelVM:updateView()
    self:callViewFunc("updateView", self.rewarded, self._mgr:isCanReward(), self.userState, self.todaySigned)
end

-- 点击贴纸
function MainPanelVM:onTagTapped(idx, layer)
    self:callViewFunc("handleClickTag", idx, layer, self.dayList, self.todaySigned)
end

-- 去闯关
function MainPanelVM:onGoBtnTapped()
    local playLevelContext = PlayLevelContext.new(_G.getTopLevelId(), PlayLevelContext.PlayType.AUTO)
    _G.amfTransaction(TransactionEvent.PLAY_LEVEL, playLevelContext)
    
    self._mgr:dc("low_active", "main_panel_click", {
        panel_id = self.panelId,
        t1 = table.count(self.dayList),  -- 下个是第几个任务
        t3 = self.versionStr,
        t4 = 1,
    })
    -- 重制强弹
    _G.amfBean("AutoPopupMgr"):resetPopup()
    self._mgr:closeAll()
end

-- 点击宝箱
function MainPanelVM:onBoxTapped()
    if self.rewarded then
        self:callViewFunc("showBoxTip", PromoteLowConst.Desc.TIP_BOX_REWARDED)
        return
    end
    if not self._mgr:isEnabled() then
        self._mgr:showErrorTip(737139)
        return
    end
    if self._mgr:isCanReward() then
        self:onGetRewardFlow()
        return
    end
    
    local signCount = table.count(self.dayList)
    local count = self.showJiCount - signCount
    self:callViewFunc("showBoxTip", string.format(PromoteLowConst.Desc.TIP_COLLECT, count))
end

-- 帮助按钮点击
function MainPanelVM:onHelpBtnTapped()
    if not EnvUtil:isApp() then return end
    local ThirdPanelAVM = require "amf.middleware.ui.kit.panel.third.ThirdPanelAVM"
    local vm
    vm = ThirdPanelAVM.Builder.new()
        :setTitle("规则说明")
        :setText("")
        :setButtonsConfig({
            {
                str = "知道了",
                touchFunc = function()
                    vm:close()
                end 
            },
        })
        :build()
    vm:popout()
    self._mgr:addVmToMgr(vm)
    self._helpVM = vm
    self:_updateHelpPanel()
end

function MainPanelVM:_updateHelpPanel()
    if not EnvUtil:isApp() then return end
    if not self._helpVM or self._helpVM.isDisposed then return end
    local curRoundEndTime = self._mgr:getValue("currentRoundEndTime")
    local leftTime = curRoundEndTime - TimeKit:timeInSec()
    if leftTime <= 0 then
        self._helpVM:close()
        return
    end
    local str = TimeKit:formatTime(leftTime)

    local text = {
        "1.每日闯关获得贴纸，贴纸集齐后赢取超强闯关道具\n",
        "2.每轮贴纸收集的时限为30个自然日（当前剩余"..str.."）"
    }
    local labelStruct = LabelStruct.new()
        :setText(text)
        :setHorizontalAlignment(kCCTextAlignmentLeft)
        :setLineSpace(10)
    self._helpVM:getUpdater():setTextStruct(labelStruct):update()
end

function MainPanelVM:onGetRewardFlow(callback)
    local function endCall()
		if self.isDisposed then return end
		self:unlock()
		-- 刷新一下界面
		self:updateView()
		safeRunCall(callback)
	end

	local function startAnim(tempRewards)
		deferred.success()
        -- 宝箱动画
        :next(function()
			local td = deferred.new()
            self:callViewFunc("tryRemoveActiveEffect")
            self:callViewFunc("updateBoxState", function()
                td:resolve()
            end, self.view.BOX_STATE.OPEN)
            return td
		end)

		-- 恭喜获得
		:next(function()
            local td = deferred.new()
            --恭喜获得
            local ShowRewardsPanelVM = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelVM"
            local vm = ShowRewardsPanelVM.Builder.new()
                :setRewards(tempRewards)
                :setCloseCallback(function()
                    td:resolve()
                end)
                :build()
            vm:popout()
            self._mgr:addVmToMgr(vm)
            return td
		end)
        :next(function()
            local td = deferred.new()
            local ret = _G.amfBean("PersonalCenterManager"):popGetNewDress(tempRewards)
            ret:setEndCallback(function()
                td:resolve()
            end)
            ret:popout()
            return td
        end)
        :next(function()
            endCall()
        end)
	end

	local function onSuccess(rewards)
		startAnim(rewards)
	end
	local function onFail()
		endCall()
	end
	self:lock()
	self._mgr:requestReward({}):next(function(rewardList)
        self:updateData()
        onSuccess(rewardList)
    end, function()
        onFail()
    end)
end

return MainPanelVM