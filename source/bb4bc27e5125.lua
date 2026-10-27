local WaterfallPanelVM = class("WaterfallProgressPanelVM", AMFBasePanelVM)
local AsyncRunner = require "amf.script.sugar.AsyncRunner"
local PaymentTracer = require 'amf.middleware.purchase.dc.trace.PaymentTracer'
local deferred = require "amf.script.sugar.deferred"
local Meta = require "amf.feature.localactivity.waterfallgiftprogress.config.Meta"


function WaterfallPanelVM:_createPanel(...)
	local WaterfallPanel = require_debug 'amf.feature.localactivity.waterfallgiftprogress.view.WaterfallProgressPanel'
	return WaterfallPanel:create(WaterfallPanelVM, ...)
end

function WaterfallPanelVM:init(mgr, delegate)
	self.mgr = mgr

	delegate = delegate or {}
    self:setCloseCallback(delegate.closeCallBack)
	if delegate.userClick == nil then
		self.userClick = true
	else
		self.userClick = delegate.userClick
	end
    self.panelSource = delegate.panelSource

	self.userData = self.mgr:getUserData() or {}
	self.actConfig = self.mgr:getActConfig() or {}
    self.endTime = self.mgr:getEndTime() or 0

	self.isDyOfferActOpen = self.mgr:isDouyinMarketing()

	self.fixedGiftCfg = self.actConfig.fixRewardNodeList

	self.curIdx = self.userData.gotRewardNodeIndex
	self.feature, self.source = self.mgr:getFeatureAndSource()
	self.panelId = UICreateUtil:getPanelId("WaterfallPanelVM")
	local progressTotalScore = self.mgr:getProgressTotalScore()
	self.mgr:dcShowPanel(self.userClick and "vine_icon" or "popoup", self.curIdx, progressTotalScore, self.panelId)
	_G.amfEC:registerNormal(NormalEvent.PASS_DAY, self.onPassDay, self)
	self:setBeltState()
end

function WaterfallPanelVM:setBeltState(refreshNow)
	self:callViewFunc("setBeltState", #self.fixedGiftCfg-self.curIdx, refreshNow)
end


function WaterfallPanelVM:onPassDay()
	-- 跨天的同时也跨期 不弹tip
	local now = TimeKit:timeInSec()
	if math.abs(now - self.endTime) > 2 then
		self:close()
		CommonTip:showTip("新的一天开始了，数据已更新，请尝试重进活动~")
	end
end

function WaterfallPanelVM:initTick()
    self.tickId = CCDirector:sharedDirector():getScheduler():scheduleScriptFunc(function ()
        if self.isDisposed then return end
        self:onTick()
    end, 1.0, false)
    self:onTick()
end

function WaterfallPanelVM:initUIWithData()
    local giftCfgList = {}
    for i = 1, 6 do
        local rewardCfg = self:getRewardCfgByIdx(self.curIdx + i)
        table.insert(giftCfgList, rewardCfg)
    end
    self:callViewFunc("updateAllGiftNode", giftCfgList, self.curIdx)
	self:initProgressBar()
end

function WaterfallPanelVM:initProgressBar()
	local info = self:getProgressNodeInfo()
	self:callViewFunc("initProgressBar", info)
end

function WaterfallPanelVM:getProgressNodeInfo()
	local progressNodeConfig = self.mgr:getProgressNodeConfig()
	local progressNodeId = self.mgr:getProgressNodeId()
	local progressTotalScore = self.mgr:getProgressTotalScore()

	local lastNodeTotalScore = 0
	local startValue, endValue, curValue = 0, 0, 0
	local rewardList
	local canGetId = 0
	for i, cfg in ipairs(progressNodeConfig) do
		if progressTotalScore < cfg.nodeTotalScore or progressNodeId < i then
			startValue = lastNodeTotalScore
			endValue = cfg.nodeTotalScore - lastNodeTotalScore
			curValue = progressTotalScore - lastNodeTotalScore
			rewardList = cfg.rewardList
			if progressTotalScore >= cfg.nodeTotalScore then
				canGetId = cfg.nodeId
			end
			break
		else
			lastNodeTotalScore = cfg.nodeTotalScore
			canGetId = cfg.nodeId
		end
	end
	printx(33, "getProgressNodeInfo", progressNodeId, canGetId, #progressNodeConfig)
	return {
		startValue = startValue,
		endValue = endValue,
		curValue = curValue,
		progressNodeId = progressNodeId,
		canGetId = canGetId,
		rewardList = rewardList,
		isFinal = (canGetId+1) == #progressNodeConfig,
	}
end

function WaterfallPanelVM:firstLoadCompleted()
	self:callViewFunc("resetNodeNodePos")
    self:initTick()
    self:initUIWithData()

	self:queryDyOfferInfo()
	self:callViewFunc("initOtherUI", self.isDyOfferActOpen)
end

function WaterfallPanelVM:tryGetProgressReward(callback)
	local progressNodeInfo = self:getProgressNodeInfo()
	local canGetId = progressNodeInfo.canGetId
	local progressNodeId = self.mgr:getProgressNodeId()
	printx(33, "tryGetProgressReward", canGetId, progressNodeId)
	if canGetId <= progressNodeId then
		safeRunCall(callback)
		return
	end

	deferred.success()
	:next(function()
		if self.isDisposed then return end
		return self:requestGetProgressRewards(progressNodeId+1)
	end)
	:next(function(rewards)
		if self.isDisposed then return end
		if self.mgr:isFinishAll() then
			return self:showFinalRewardPanel(rewards)
		else
			return self:flyProgressReward(rewards, progressNodeInfo.isFinal):next(function()
				if self.isDisposed then return end
				local progressInfo = self:getProgressNodeInfo()
				self:callViewFunc("setProgressBarZero", progressInfo)
				self:callViewFunc("setProgressBarRewardList", progressInfo)
				return self:playProgressBarAddAnim(progressInfo)
			end)			
		end
	end)
	:next(function()
		if self.mgr:isFinishAll() then
			self.mgr:onDeprecated()
		end
		safeRunCall(callback)
	end, function()
		safeRunCall(callback)
	end)
end

function WaterfallPanelVM:requestGetProgressRewards(id)
	local d = deferred.new()
	self.mgr:requestGetProgressRewards(id, function(rewards)
		if self.isDisposed then return end
		self.mgr:dc("falls_gift", "plan_reward", id, nil, nil, nil, {panel_id = self.panelId})
		d:resolve(rewards)
	end, function()
		d:reject()
	end)
	return d
end

function WaterfallPanelVM:flyProgressReward(rewards, isFinal)
	local d = deferred.new()
	self:callViewFunc("flyProgressReward", rewards, isFinal, function()
		if self.isDisposed then return end
		d:resolve()
	end)
	return d
end

function WaterfallPanelVM:showFinalRewardPanel(rewardList)
	local d = deferred.new()
	local boxAnim = UICreateUtil:createSpineManuallyRelease("amf/uikit/spine/boxAnim/xinbaoxiang5ji.skel")
    boxAnim:setScale(0.7)
    boxAnim.playAnim = function(animName, done)
        boxAnim:playOnce(animName, done)
    end
    boxAnim.playShowAnim = function(done)
        boxAnim.playAnim('in', function()
            if boxAnim.isDisposed then return end
            boxAnim.playAnim('kaixiang', done)
        end)
    end
    boxAnim.playDisappearAnim = function(done)
        boxAnim.playAnim('xiaoshi', done)
    end

    boxAnim.playIdleAnim = function(done)
        boxAnim:playByName("idle", true)
    end
	local ShowRewardsPanelCVM = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelCVM"
	local vm = ShowRewardsPanelCVM.Builder.new()
	:setTitle("获得宝藏大奖")
	:setButtonText("收下")
	:setRewards(rewardList)
	:setBoxAnim(boxAnim)
	:setCloseCallback(function()
		d:resolve()
	end)
	:build()
	vm:popout()
	return d
end

function WaterfallPanelVM:playProgressBarAddAnim()
	local d = deferred.new()
	local progressInfo = self:getProgressNodeInfo()
	-- printx(33, "playProgressBarAddAnim", tts(progressInfo))
	self:callViewFunc("playProgressBarAddAnim", progressInfo, function()
		if self.isDisposed then return end
		d:resolve()
	end)
	return d
end

function WaterfallPanelVM:onProgressRewardTapped()
	printx(33, "onProgressRewardTapped")
	if self.isDisposed then return end
	if self:isLocked() then return end
	if self.mgr:isFinishAll() then return end
	local progressInfo = self:getProgressNodeInfo()
	local rewardList = progressInfo.rewardList
	local endValue = progressInfo.endValue
	local curValue = progressInfo.curValue
	local nodeId = progressInfo.progressNodeId
	local progressNodeConfig = self.mgr:getProgressNodeConfig()
	self:callViewFunc("showProgressRewardTip", rewardList, endValue - curValue, nodeId == #progressNodeConfig)
end

function WaterfallPanelVM:onProgressBarTapped()
	printx(33, "onProgressBarTapped")
	if self.isDisposed then return end
	if self:isLocked() then return end
	local WaterfallProgressDetailPanelVM = require "amf.feature.localactivity.waterfallgiftprogress.view.WaterfallProgressDetailPanelVM"
	local vm = WaterfallProgressDetailPanelVM:create()
	vm:popout()
end

function WaterfallPanelVM:onProgressItemTapped()
	if self.isDisposed then return end
	if self:isLocked() then return end
	self:callViewFunc("showProgressItemTip")
end

function WaterfallPanelVM:onCloseBtnTapped()
    if self.isDisposed then return end
    -- if self:isLocked() then return end

    self:close()

	if EnvUtil:isDevelopMode() then
		if self.testUtils then
			self.testUtils:close()
		end
	end
end

function WaterfallPanelVM:onTick()
    if self.isDisposed then return end

    if TimeKit:timeInSec() >= self.endTime then
		if self.mgr:isFinishAll() then
			self.mgr:onDeprecated()
		else
			self.mgr:setEnterAwardTime()
		end
        
        self:close()
        CommonTip:showTip("活动已结束")
        return
    end

    self:callViewFunc("updateTitle", self.endTime)
	self:tryUpdateGuideHand()
end

function WaterfallPanelVM:tryUpdateGuideHand()
	if self.hasShowedGuideHand then return end
	if not self.lastTickGuideHandTime then
		self.lastTickGuideHandTime = TimeKit:timeInSec()
		return
	end
	if TimeKit:timeInSec() - self.lastTickGuideHandTime >= 3 then
		self:callViewFunc("showGuideHand")
		self.hasShowedGuideHand = true
	end
end

function WaterfallPanelVM:onEnterPanelRun()
	printx(33, "onEnterPanelRun")
    if self.isDisposed then return end
    -- if self:isLocked() then return end

    self:lockWithoutBlock()
	local asyncRunner = AsyncRunner:create()

	asyncRunner:add(function(done)
        if self.isDisposed then return end
        printx(33, "playEnterAnim")
        self:callViewFunc("playEnterAnim", done)
	end)

	asyncRunner:add(function(done)
        if self.isDisposed then return end
		printx(33, "tryGetProgressReward")
		self:tryGetProgressReward(function()
			if self.isDisposed then return end
			safeRunCall(done)
		end)
	end)

	asyncRunner:add(function(done)
		if self.isDisposed then return end
		printx(33, "checkPeriodOpenTip")
		if not self.mgr:getHasShownPeriodOpenTip() then
			self:callViewFunc("showProgressItemTip")
			self.mgr:setHasShowPeriodOpenTip()
		end
		self:unlockWithoutBlock()
	end)

	asyncRunner:run()
end


function WaterfallPanelVM:playBuySuccess(curIdx, giftCfg, serverRewards, callback)
	local asyncRunner = AsyncRunner:create()
	asyncRunner:add(function(done)
		if self.isDisposed then return end
		self:callViewFunc("setButtonBuySuccess", done)
	end)

	asyncRunner:add(function(done)
		if self.isDisposed then return end
		self:callViewFunc("doNodeFlyFunc", serverRewards, done)
	end)

	asyncRunner:add(function(done)
		if self.isDisposed then return end
		self:callViewFunc("playButtonUnlockAnim", done)
	end)

	asyncRunner:add(function(done)
		if self.isDisposed then return end
		self:callViewFunc("playNodeMove", giftCfg, curIdx, done)
		setTimeOut(function()
			if self.isDisposed then return end
			self:setBeltState(true)
		end, 0.15)
	end)

	asyncRunner:add(function(done)
		if self.isDisposed then return end
		self:callViewFunc("updateBtnBreath")
		if self:callViewFunc("checkNodeClear") then
			self:callViewFunc("showNodeClearUI")
			self.mgr:setEnterAwardTime()
		end
		self:tryGetProgressReward(done)
	end)

	-- asyncRunner:add(function(done)
	-- 	if self.isDisposed then return end
	-- 	if self.mgr:isFinishAll() then
	-- 		self:close()
	-- 		self.mgr:onDeprecated()
	-- 		return
	-- 	else
	-- 		done()
	-- 	end
	-- end)

	asyncRunner:add(function(done)
		if self.isDisposed then return end
		safeRunCall(callback)
	end)
	asyncRunner:run()
end


function WaterfallPanelVM:onBuyBtnTapped(node, nodeIdx)
    if self.isDisposed then return end
	if self:isLocked() then return end
	
	-- do 
	-- 	self:callViewFunc("testNodeFlyFunc")
	-- 	return		
	-- end


	if nodeIdx ~= self.curIdx + 1 then
		if node and node.btn then
            self:callViewFunc("popBeforeRewardTip", node.btn)
		end
		return
	end

	self:lockWithoutBlock()
	self:callViewFunc("hideGuideHand")
	if node.tracer then
		node.tracer:click()
	end

	local function onSuccess(serverRewards)
        if node.tracer then
        	node.tracer:paySuccess()
        end
		self.mgr:dcJoin()
		self.mgr:addSpecialRewardNum(nodeIdx)
        self.curIdx = self.curIdx + 1
		self.mgr:updateCurIdx(self.curIdx)
        local rewardCfg = self:getRewardCfgByIdx(self.curIdx+6)
        self:playBuySuccess(self.curIdx, rewardCfg, serverRewards, function()
			if self.isDisposed then return end
			if node.isFree then
				local specialNum = self.mgr:getSpecialRewardNumById(nodeIdx)
				self.mgr:dc("falls_gift", "get_reward", nodeIdx, specialNum, nil, nil, {panel_id = self.panelId})
			end
			printx(33, "playBuySuccess callback")
            self:unlockWithoutBlock()
		end)

		self:callViewFunc("setDyOfferUpdate", nil)

		if (not node.isFree) or (not self.dyOfferInfo) then
			self:queryDyOfferInfo()
		end
	end
	local function onFail()
		self:unlockWithoutBlock()
		if node.tracer then
			node.tracer:payFail()
		end
	end
	local function onCancel()
		self:unlockWithoutBlock()
		if node.tracer then
			node.tracer:payCancel()
		end
	end

	if node.isFree then
		self:doGetFreeReward(self.curIdx+1, onSuccess, onFail, onCancel)
	else
		self:doUnifiedBuy(node.goodsId, onSuccess, onFail, onCancel)
	end
end

function WaterfallPanelVM:getRewardCfgByIdx(idx)
	local ret = self.fixedGiftCfg[idx]
	if (self.stopCreateIdx and idx >= self.stopCreateIdx) then
		if not self.stopCreateIdx then
			self.stopCreateIdx = idx
		end
		ret = nil
	end

	if ret and ret.goodsId and ret.goodsId ~= 0 then
		ret.tracer = PaymentTracer.createRMBPayTracer(
            self.feature,
            self.source,
            ret.goodsId,
            self.userClick and DCPayProgressPayPanelShowType.kUserClick or DCPayProgressPayPanelShowType.kAutoPopout,
            {panel_source = self.panelSource}
        )
	end
	return ret
end

function WaterfallPanelVM:doUnifiedBuy(goodsId, onSuccess, onFail, onCancel)
    local function successCallback(payInfo)
		local rewards = payInfo and payInfo.serverRewards or {}
        if onSuccess then
            onSuccess(rewards)
        end

		self.mgr:onPaySuccess(payInfo.payType)
    end

	local stageType = GiftPackageConst.StageType.ACTIVITY
	local moduleName = self.mgr:getGiftModuleName()
    local buyContext = BuyContext.new(goodsId, MoneyType.kRmb)
                                 :setFeatureAndSource(self.feature, self.source)
                                 :setUnifiedBuy(true, stageType, moduleName)
                                 :setCallback(successCallback, onFail, onCancel)

	if self.isDyOfferActOpen then
		buyContext:setPriorityPayType(Payments.DOUYIN_ANDROID)
		if self.dyOfferInfo and self.dyOfferInfo.assignDiscountKey then
			buyContext:setPreOrderExtraInfo({
				assignDiscountKey = self.dyOfferInfo.assignDiscountKey,
				dyGoodsTagActKey = Meta.ModuleName,
			})
		end
	end
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
end

function WaterfallPanelVM:doGetFreeReward(id, onSuccess, onFail, onCancel)
	self.mgr:requestFreeNodeReward(id, onSuccess, onFail, onCancel)
end

function WaterfallPanelVM:recycle()
    _G.amfEC:unregisterNormal(NormalEvent.PASS_DAY, self.onPassDay)

    if self.tickId then
        CCDirector:sharedDirector():getScheduler():unscheduleScriptEntry(self.tickId)
        self.tickId = nil
    end
	_G.amfEC:unregisterNormal(NormalEvent.PASS_DAY, self.onPassDay)
    AMFBasePanelVM.recycle(self)
end

function WaterfallPanelVM:queryDyOfferInfo()
	if not self.isDyOfferActOpen then return end
	self.dyOfferInfo = nil
	self.mgr:findThenQueryDyOffer():next(function(dyOfferInfo)
		if dyOfferInfo then
			self.dyOfferInfo = dyOfferInfo
			self:callViewFunc("setDyOfferUpdate", dyOfferInfo)
		end
	end)
end

function WaterfallPanelVM:onPanelReady()
	AMFBasePanelVM.onPanelReady(self)


	if EnvUtil:isDevelopMode() then
		self:createTestBtn()
	end
end

function WaterfallPanelVM:createTestBtn()
    local TestUtils = require("amf.feature.localactivity.waterfallgift.view.TestUtils")
    if EnvUtil:isDevelopMode() then
        if not self.testUtils then
            self.testUtils = TestUtils.new()
        end
        self.testUtils:showTest(self)
        self.testUtils.testButtonCtrl.onTapped()
    end
end


return WaterfallPanelVM
