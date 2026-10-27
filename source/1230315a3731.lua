local WaterfallPanelVM = class("WaterfallPanelVM", AMFBasePanelVM)
local AsyncRunner = require "amf.script.sugar.AsyncRunner"
local PaymentTracer = require 'amf.middleware.purchase.dc.trace.PaymentTracer'

function WaterfallPanelVM:_createPanel(...)
	local WaterfallPanel = force_require 'amf.feature.localactivity.waterfallgift.view.WaterfallPanel'
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
	self.mgr:dcShowPanel(self.userClick and "vine_icon" or "popoup", 1, self.panelId)
	_G.amfEC:registerNormal(NormalEvent.PASS_DAY, self.onPassDay, self)
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
end

function WaterfallPanelVM:firstLoadCompleted()
    self:initTick()
    self:initUIWithData()

	self:queryDyOfferInfo()
	self:callViewFunc("initOtherUI", self.isDyOfferActOpen)
end

function WaterfallPanelVM:onCloseBtnTapped()
    if self.isDisposed then return end
    if self:isLocked() then return end

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
        self.mgr:onDeprecated()
        self:close()
        CommonTip:showTip("活动已结束")
        return
    end

    self:callViewFunc("updateTitle", self.endTime)
end

function WaterfallPanelVM:onEnterPanelRun()
    if self.isDisposed then return end
    if self:isLocked() then return end

    self:lock()
	local asyncRunner = AsyncRunner:create()

	asyncRunner:add(function(done)
        if self.isDisposed then return end
        self:callViewFunc("playEnterAnim", done)
	end)

	asyncRunner:add(function(done)
		if self.isDisposed then return end
		self:unlock()
	end)

	asyncRunner:run()
end


function WaterfallPanelVM:onBuyBtnTapped(node, nodeIdx)
    if self.isDisposed then return end
	if self:isLocked() then return end

	if nodeIdx ~= self.curIdx + 1 then
		if node and node.btn then
            self:callViewFunc("popBeforeRewardTip", node.btn)
		end
		return
	end

	self:lock()

	if node.tracer then
		node.tracer:click()
	end

	local function onSuccess(serverRewards)
        if node.tracer then
        	node.tracer:paySuccess()
        end
		self.mgr:dcJoin()
        self.curIdx = self.curIdx + 1
		self.mgr:updateCurIdx(self.curIdx)
        local rewardCfg = self:getRewardCfgByIdx(self.curIdx+6)
        self:callViewFunc("playBuySuccess", self.curIdx, rewardCfg, serverRewards, function(needClose)
			if self.isDisposed then return end

			if node.isFree then
				self.mgr:dc("sprog_icebreaking", "get_reward", nodeIdx)
			end

			if needClose then
				self:close()
				self.mgr:onDeprecated()
                return
			end

            self:unlock()
		end)

		self:callViewFunc("setDyOfferUpdate", nil)

		if (not node.isFree) or (not self.dyOfferInfo) then
			self:queryDyOfferInfo()
		end
	end
	local function onFail()
		self:unlock()
		if node.tracer then
			node.tracer:payFail()
		end
	end
	local function onCancel()
		self:unlock()
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
				dyGoodsTagActKey = not self.mgr:isDouyinRandomMarketing() and "waterfall2025" or nil
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
