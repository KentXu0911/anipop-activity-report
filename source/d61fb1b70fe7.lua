local LuaQueue = require "amf.script.datastruct.LuaQueue"
local UIButton = require "amf.middleware.ui.kit.component.button.UIButton"
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local AsyncRunner = require "amf.script.sugar.AsyncRunner"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local Meta = require "amf.feature.localactivity.waterfallgift.config.Meta"
local MultiLabel = require("amf.middleware.ui.kit.component.multilabel.MultiLabel")
local WaterfallWeakFlyAnim = require_debug "amf.feature.localactivity.waterfallgiftprogress.view.WaterfallWeakFlyAnim"
---@class WaterfallPanel : AMFBasePanel
local WaterfallPanel = class("WaterfallProgressPanel", AMFBasePanel)

local FRAMETIME = 1/30

local RewardPos = {
	[1] = {
		pos = {
			{x = 0, y = -3},
		},
		scale = 0.8,
	},
	[2] = {
		pos = {
			{x = -45, y = -3},
			{x = 45, y = -3},
		},
		scale = 0.8,
	},
	[3] = {
		pos = {
			{x = 0, y = 45},
			{x = -60, y = -16},
			{x = 60, y = -16},
		},
		scale = 0.6,
	}
}

local horizontalSpace = 348
local verticalSpace = 340

local NodeMovePos = {
	[1] = {x = 0, y = 0},
	[2] = {x = -horizontalSpace, y = 0},
	[3] = {x = 0, y = verticalSpace},
	[4] = {x = horizontalSpace, y = 0},
	[5] = {x = 0, y = verticalSpace},
	[6] = {x = -horizontalSpace, y = 0},
}

function WaterfallPanel:getUIInfo()
    local path = "amf.feature.localactivity.waterfallgiftprogress.view.uisource.WaterfallProgressPanel_UI"
    local skipList = {"node", "lock"}

    return path, skipList
end

function WaterfallPanel:getAssetsList()
    local ret = {
		-- "amf/activity/newbiegiftoptimize/spine/changjiazhixiao.skel",
		"amf/store/layout/GiftGoldIcon.plist",
		'amf/store/spine/light_down_new.skel',
		"amf/activity/waterfallprogress/spine/lixiongbaozang.skel",
		"amf/activity/waterfallprogress/materials/specialIcon.png",
		"amf/activity/waterfallprogress/spine/reward_vfx.skel",
		"amf/activity/waterfallprogress/spine/icon_fx.skel",
	}
    return ret
end

function WaterfallPanel:init(delegate)
	self:initBelts()
	self:initGiftNode()
	self:initButtons()
	self.finalText:setVisible(false)
end

function WaterfallPanel:initBelts()
	-- local belt = UICreateUtil:createSpine("amf/activity/newbiegiftoptimize/spine/changjiazhixiao.skel")
	-- self.beltNode:addChild(belt)
	-- belt:setPositionXY(315, -783)
	-- self.beltAnim = belt
	-- belt:playLoop("idle")

	local pos = {
		{x = 360, y = -571, rot = 0},
		{x = 535, y = -744, rot = 90},
		{x = 355, y = -912, rot = 180},
		{x = 188, y = -1085, rot = 90},
		{x = 360, y = -1261, rot = 0},
	}
	for i = 2, 6 do
		local arrow = UICreateUtil:createSpine("amf/activity/waterfallprogress/spine/lixiongbaozang.skel")
		arrow:setName("arrow"..i)
		self.beltNode:addChild(arrow)
		self["arrow"..i] = arrow
		arrow:setPositionXY(pos[i-1].x, pos[i-1].y)
		arrow:setRotation(pos[i-1].rot)
		-- arrow:setVisible(false)
		arrow:setScale(0)
	end
	LayoutUtil:move(self.trackNode, 10, -40)
end

function WaterfallPanel:setBeltState(num, refreshNow)
	self.beltState = num
	if refreshNow then
		for i = 2, 6 do
			-- self["arrow"..i]:setVisible(i <= self.beltState)
			self["arrow"..i]:setScale(i <= self.beltState and 1 or 0)
		end
		setTimeOut(function()
			if self.isDisposed then return end
			for i = 2, 6 do
				if i > self.beltState then
					if i == 2 then
						self.start2:setVisible(false)
						self.track2:setVisible(false)
						self.end2:setVisible(false)
					elseif i <= 6 then
						local track1 = self["track"..i.."_1"]
						if track1 then
							track1:setVisible(false)
						end
						local track2 = self["track"..i.."_2"]
						if track2 then
							track2:setVisible(false)
						end
						local end1 = self["end"..i]
						if end1 then
							end1:setVisible(false)
						end
					end
				end
			end
		end, 5*FRAMETIME)
	end
end

function WaterfallPanel:initGiftNode()
	self.nodeQueue = LuaQueue:create()
end

function WaterfallPanel:initButtons()
	self.closeBtn:setTouchHandler(preventContinuousClick(function()
		if self.isDisposed then return end
		self:sendCommand("onCloseBtnTapped")
	end))
end

function WaterfallPanel:resetNodeNodePos()
	LayoutUtil:move(self.nodeNode, 30, -10)
	self.node1:setPositionXY(0, 0)
	self.node2:setPositionXY(horizontalSpace, 0)
	self.node3:setPositionXY(horizontalSpace, -verticalSpace)
	self.node4:setPositionXY(0, -verticalSpace)
	self.node5:setPositionXY(0, -verticalSpace*2)
	self.node6:setPositionXY(horizontalSpace, -verticalSpace*2)
end

function WaterfallPanel:updateAllGiftNode(giftCfgList, curIdx)
	self.nodeQueue:clear()
	giftCfgList = giftCfgList or {}
	for i = 1, 6 do
		self["node"..i]:removeChildren(true)
		local giftCfg = giftCfgList[i]
		if giftCfg then
			local node = self:createGiftNode(giftCfg, curIdx, curIdx + i)
			self["node"..i]:addChild(node)
			self.nodeQueue:pushBack(node)
			if node.tracer then
				node.tracer:show()
			end
		end
	end

	for i = 5, 1, -1 do
		local node = self["node"..i]
		local parent = node:getParent()
		node:removeFromParentAndCleanup(false)
		parent:addChild(node)
	end
end

function WaterfallPanel:updateTitle(endTimeInSec)
	local timeFormat = TimeUtil:timeFormatVer1({
		endTimeInSec = endTimeInSec
	})

	local timeStr
	if timeFormat.retString == "" then
		timeStr = "00:00:00"
	else
		timeStr = timeFormat.retString
	end
	self.timeLabel1:setString(YH_REF_MAP.noEarClock..timeStr, true)
	self.timeLabel2:setString(YH_REF_MAP.noEarClock..timeStr, true)
end

function WaterfallPanel:updateBtnBreath()
	local node = self.nodeQueue:getFront()
	if node and node.btn then
		node.btn:runBreathAnimation()
	end
end

function WaterfallPanel:createGiftNode(cfg, curIdx, nodeIdx)
	if not cfg then return end

	local node, cls = self.builder:createChild("node")
	for i, v in pairs(cls) do
		node[i] = v
	end
	node.normalBg:setVisible(cfg.freeNode)
	node.yellowBg:setVisible(not cfg.freeNode)
	local price = 0
	if not cfg.freeNode then
		price = GoodsManager:getGoods(cfg.goodsId):getPrice()
	end
	local btn = UIButton:createButton({
		scaleMode = UIButtonConfig.BtnScales.k60,
		colorMode = cfg.freeNode and UIButtonConfig.ColorMode.green or UIButtonConfig.ColorMode.blue,
	})
	btn:setCallBack(function()
		self:sendCommand("onBuyBtnTapped", node, nodeIdx)
	end)

	self:setButtonString(btn, cfg, cfg.freeNode and nodeIdx ~= curIdx + 1)
	node.buttonNode:addChild(btn)
	btn:setName("nodeBtn")
	node.btn = btn

	local specialNum = cfg.specialValue2 and tonumber(cfg.specialValue2) or 0
	if specialNum > 0 then
		node.collectionLabel:setString(string.format("%d", specialNum))
		node.normalCollectionBg:setVisible(cfg.freeNode)
		node.yellowCollectionBg:setVisible(not cfg.freeNode)
		node.specialNum = specialNum
	else
		node.collectionNode:setVisible(false)
	end

	local rewardList = {}
	if cfg.freeNode then
		rewardList = cfg.rewardList
	else
		local goodsObj = GoodsManager:getGoods(cfg.goodsId)
		if goodsObj then
			rewardList = goodsObj:getItems()
		end
	end
	node.rewardList = rewardList
	local rewardNum = #rewardList
	if rewardNum == 1 and rewardList[1].itemId == UPropId.GOLD then
		local GiftGoldIcon = require "amf.feature.store.view.gift.layout.GiftGoldIcon"
		local icon = GiftGoldIcon:create(rewardList[1].num)
		icon:setScale(0.8)
		node:getChildByName("rewardNode"):addChild(icon)
		node.flyFunc = function(callback)
			if self.isDisposed then return end
			self:flyNodeReward(node, rewardList, callback)
		end
	elseif rewardNum > 3 then
		local icon = AMFCompHelper:createBoxHong(false, true)
		node:getChildByName("rewardNode"):addChild(icon)
		icon:setTouchHandler(function()
			if self.isDisposed then return end
			-- if self:isLocked() then return end
			printx(33, "box hong touched")
			UITip.Builder.new()
				:setTitle("领取如下奖励：")
				:setRewards(rewardList)
				:setTarget(icon)
				:setAutoCloseTime(3)
				:build()
		end)
		node.flyFunc = function(callback)
			if self.isDisposed then return end
			setTimeOut(function()
				if self.isDisposed then return end
				icon:changeDisplayByFrameName("common/icon_256/icon_baoxiang_siji_256_02")
				self:flyNodeReward(node, rewardList, callback)
			end, 2*FRAMETIME)
		end
	else
		local tmpIconList = {}
		for i, v in ipairs(rewardList) do
			local icon = GameItemCreator:getPropIcon({itemId = v.itemId, num = v.num, needNum = false})
			if not _G.amfBean("PropManager"):isInfiniteProp(v.itemId) then
				local numLabel, diffx, diffy = AMFCompHelper:createPropNum({
					itemId = v.itemId,
					num = v.num,
					outlineColor = cfg.freeNode and "A5590EFF" or "A5590EFF",
				})
				local sz = icon:getContentSize()
				numLabel:setPositionXY(sz.width + diffx, diffy)
				icon:addChild(numLabel)
				numLabel:setScale(0.9/RewardPos[rewardNum].scale)
			end
			node:getChildByName("rewardNode"):addChild(icon)
			local pos = RewardPos[rewardNum].pos[i]
			icon:setPositionXY(pos.x, pos.y)
			icon:setScale(RewardPos[rewardNum].scale)
			table.insert(tmpIconList, icon)
		end
		node.flyFunc = function(callback, serverRewardList)
			if self.isDisposed then return end
			self:flyNodeReward(node, serverRewardList or rewardList, callback)
		end
	end

	node:setPositionXY(0, 0)
	node.isFree = cfg.freeNode
	node.rewardList = rewardList
	node.goodsId = cfg.goodsId
	node.tracer = cfg.tracer
	node.nodeIdx = nodeIdx
	return node
end

function WaterfallPanel:initProgressBar(info)
	local startValue = info.startValue
	local endValue = info.endValue
	local curValue = info.curValue
	local rewardList = info.rewardList

	self.progressBar:setPercentage((curValue)/(endValue))
	self.progressBar:setProgressText(tostring(curValue).."/"..tostring(endValue))

	local boxNode = LayerColor:create()
	boxNode:setContentSize(CCSizeMake(80,80))
	boxNode:setColor(ccc3(255,0,0))
	boxNode:setPositionXY(250, -39)
	boxNode:setOpacity(0)
	self.progressBar:addChild(boxNode)
	self.progressRewardNode = boxNode
	boxNode:setTouchHandler(function()
		if self.isDisposed then return end
		self:sendCommand("onProgressRewardTapped")
	end)

	local itemNode = LayerColor:create()
	itemNode:setContentSize(CCSizeMake(80,80))
	itemNode:setColor(ccc3(0,0,255))
	itemNode:setOpacity(0)
	itemNode:setPositionXY(-320, -39)
	self.progressBar:addChild(itemNode)
	itemNode:setTouchHandler(function()
		if self.isDisposed then return end
		self:sendCommand("onProgressItemTapped")
	end)
	self.progressItemNode = itemNode

	local progressBarLayer = LayerColor:create()
	progressBarLayer:setContentSize(CCSizeMake(490,55))
	progressBarLayer:setColor(ccc3(0,255,0))
	progressBarLayer:setOpacity(0)
	progressBarLayer:setPositionXY(-250, -29)
	self.progressBar:addChild(progressBarLayer)
	self:setProgressBarRewardList(info)
	progressBarLayer:setTouchHandler(function()
		if self.isDisposed then return end
		self:sendCommand("onProgressBarTapped")
	end)
end

function WaterfallPanel:doUIAdjust()
	local UIDecorator = require "amf.middleware.ui.util.adaptation.UIDecorator"
    local panelMargin = UIDecorator:panelMargin(self)
	UIDecorator:adaptCloseBtn(self)
    panelMargin:addCenterTop(self.titleNode, 0, 0, self.title1)
	:addClose(self.closeBtn)
	:layout()
end

function WaterfallPanel:beforePopoutAnim()
    if self._delayDispose then return end

	self:handleOnEnter()
end

function WaterfallPanel:handleOnEnter()
	self.nodeQueue:foreach(function(index, node)
		if not node or node.isDisposed then return end
		LayoutUtil:move(node, 0, -219.02)

		ActionUtil:setOpacityU3D(node:getChildByName("normalBg"), 0)
		ActionUtil:setOpacityU3D(node:getChildByName("yellowBg"), 0)
		ActionUtil:setOpacityU3D(node:getChildByName("buttonNode"), 0)
		ActionUtil:setOpacityU3D(node:getChildByName("rewardNode"), 0)
		ActionUtil:setOpacityU3D(node:getChildByName("collectionNode"), 0)
	end)

	ActionUtil:setOpacityU3D(self.bg, 0)
	ActionUtil:setOpacityU3D(self.titleNode, 0)
	ActionUtil:setOpacityU3D(self.closeBtn, 0)
	-- self.beltAnim:playOnce("in", function()
	-- 	if self.isDisposed then return end
	-- 	self.beltAnim:playLoop("idle")
	-- end)
	-- self.beltAnim:pause()
end

function WaterfallPanel:setButtonString(btn, cfg, hasLock)
	local param = {}
	if hasLock then
		local layer = Layer:create()
		layer:setContentSize(CCSizeMake(20, 20))
		local lock = UICreateUtil:createSpine("amf/activity/waterfallprogress/spine/lixiongbaozang.skel")
		lock:gotoAndStop("jiesuo", 0)

		btn.lockAnim = lock
		lock:setScale(0.45)
		lock:setPositionXY(10, 9)
		layer:addChild(lock)
		layer:ignoreAnchorPointForPosition(false)
		layer:setAnchorPoint(ccp(0.5, 0.5))
		table.insert(param, layer)
	end
	local price
	if cfg.goodsId then
		price = GoodsManager:getGoods(cfg.goodsId):getPrice()
	end
	local str = cfg.freeNode and "免费" or "￥"..price
	table.insert(param, str)
	btn:update(param)
	if not cfg.freeNode then
		btn:setRmbPrice(price)
	end
end

function WaterfallPanel:popBeforeRewardTip(target)
	UITip.Builder.new()
		:setTitle("领取之前的礼品可解锁")
		:setTarget(target)
		:setAutoCloseTime(3)
		:build()
end

function WaterfallPanel:setButtonBuySuccess(callback)
	local node = self.nodeQueue:getFront()
	-- local label = TTFLabel:createAnimalYH("已领取", 34)
	-- label:setAnchorPoint(ccp(0.5, 0.5))
	-- label:setTextColor(hex2ccc4("6471C4FF"))
	-- node:getChildByName("buttonNode"):addChildAt(label, 0)
	local btn = node:getChildByName("buttonNode"):getChildByName("nodeBtn")
	local rewardNode = node:getChildByName("rewardNode")
	rewardNode:runAction(ActionUtil:fadeToU3D(rewardNode, 3*FRAMETIME, 46))
	local checkIcon = Sprite:createWithSpriteFrameName("other/common/ui_com_big_gou")
	checkIcon:setScale(0.5)
	node:addChild(checkIcon)
	checkIcon:setPositionXY(153, 77)
	checkIcon:setOpacity(0)
	checkIcon:runAction(CCFadeTo:create(3*FRAMETIME, 255))
	btn:playClickDisappearAnim(callback)

	if node.dyMarkNode then
		node.dyMarkNode:removeFromParentAndCleanup(true)
		node.dyMarkNode = nil
	end
end

function WaterfallPanel:doNodeFlyFunc(serverRewards, callback)
	if self.isDisposed then return end
	local curNode = self.nodeQueue:getFront()
	curNode.flyFunc(callback, serverRewards)
end

function WaterfallPanel:testNodeFlyFunc(callback)
	local curNode = self.nodeQueue:getFront()
	local rewardList = curNode.rewardList
	curNode.flyFunc(callback, rewardList)
end

function WaterfallPanel:playButtonUnlockAnim(callback)
	local node = self.nodeQueue.queue[self.nodeQueue.first+1]
	if node and node.btn and node.btn.lockAnim then
		local oriLock = node.btn.lockAnim
		local pos = oriLock:getPositionInWorldSpace()
		local lockAnim = UICreateUtil:createSpine("amf/activity/waterfallprogress/spine/lixiongbaozang.skel")
		self:addChild(lockAnim)
		lockAnim:setPositionInWorldSpace(ccp(pos.x, pos.y))
		lockAnim:playOnceAndDispose("jiesuo", function()
			if self.isDisposed then return end
			callback()
		end)
		self:setButtonString(node.btn, {freeNode = true}, false)
	else
		callback()
	end
end

function WaterfallPanel:playNodeMove(giftCfg, curIdx, callback)
	self.nodeQueue:foreach(function(index, node)
		if not node or node.isDisposed then return end
		if index == 1 then
			node:runAction(ActionUtil:spawn{
				CCEaseSineInOut:create(CCScaleTo:create(7*FRAMETIME, 0.9, 0.9)),
				ActionUtil:sequence{
					CCDelayTime:create(4*FRAMETIME),
					ActionUtil:fadeOutU3D(node, 3*FRAMETIME),
					CCCallFunc:create(function()
						node:removeFromParentAndCleanup(true)
						safeRunCall(callback)
					end)
				},
			})
		else
			local targetPos = NodeMovePos[index]
			node:runAction(ActionUtil:sequence{
				CCDelayTime:create((index - 1)*2*FRAMETIME),
				ActionUtil:spawn{
					CCEaseSineInOut:create(CCMoveBy:create(10*FRAMETIME, ccp(targetPos.x, targetPos.y))),
					ActionUtil:sequence{
						CCEaseSineInOut:create(CCScaleTo:create(5*FRAMETIME, 0.9)),
						CCEaseSineInOut:create(CCScaleTo:create(5*FRAMETIME, 1)),
					}
				}
			})
		end
	end)

	self.nodeQueue:popFront()

	local nextNode = self:createGiftNode(giftCfg, curIdx, curIdx + 6)
	if nextNode then
		self.node6:addChild(nextNode)
		self.nodeQueue:pushBack(nextNode)

		if nextNode.tracer then
			nextNode.tracer:show()
		end

		ActionUtil:setOpacityU3D(nextNode, 0)
		nextNode:setPositionXY(0, -320)
		nextNode:runAction(ActionUtil:sequence{
			CCDelayTime:create(12*FRAMETIME),
			ActionUtil:spawn{
				CCMoveBy:create(10*FRAMETIME, ccp(0, 320)),
				ActionUtil:fadeInU3D(nextNode, 3*FRAMETIME),
				ActionUtil:sequence{
					CCScaleTo:create(5*FRAMETIME, 0.9),
					CCScaleTo:create(5*FRAMETIME, 1),
					CCCallFunc:create(function()
						self:dp(AMFEvent.new("GIFT_QUEUE_UPDATE_END"))
					end)
				}
			}
		})
	end
end

function WaterfallPanel:checkNodeClear()
	return self.nodeQueue:getSize() == 0
end

function WaterfallPanel:showNodeClearUI()
	self.finalText:setVisible(true)
end

function WaterfallPanel:showRmbRewardPanel(rewardList, callback)
	local ShowRewardsPanelVM = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelVM"
	local vm = ShowRewardsPanelVM.Builder.new()
		:setRewards(rewardList)
		:setCloseCallback(callback)
		:setButtonText("收下")
		:build()
		:popout()
end

function WaterfallPanel:beltShowAnim()
	printx(33, "WaterfallPanel:beltShowAnim", self.beltState)
	for i = 2, 6 do
		if i <= self.beltState then
			-- self["arrow"..i]:setVisible(true)
			self["arrow"..i]:setScale(1)
			self["arrow"..i]:playOnce("in", function()
				if self.isDisposed then return end
				self["arrow"..i]:playLoop("yuandi-idle")
			end)
			local animTime = 10*FRAMETIME
			self.start2:setVisible(true)
			self.track2:setVisible(true)
			self.end2:setVisible(true)
			self.start2:setOpacity(0)
			self.track2:setOpacity(0)
			self.end2:setOpacity(0)
			self.start2:runAction(CCFadeIn:create(animTime))
			self.track2:runAction(CCFadeIn:create(animTime))
			self.end2:runAction(CCFadeIn:create(animTime))
			if i >= 3 and i <= 6 then
				local track1 = self["track"..i.."_1"]
				if track1 then
					track1:setOpacity(0)
					track1:setVisible(true)
					track1:runAction(CCFadeIn:create(animTime))
				end
				local track2 = self["track"..i.."_2"]
				if track2 then
					track2:setOpacity(0)
					track2:setVisible(true)
					track2:runAction(CCFadeIn:create(animTime))
				end
				local end1 = self["end"..i]
				if end1 then
					end1:setOpacity(0)
					end1:setVisible(true)
					end1:runAction(CCFadeIn:create(animTime))
				end
			end
		end
	end
end

function WaterfallPanel:playEnterAnim(callback)
	self.bg:runAction(ActionUtil:fadeInU3D(self.bg, 3*FRAMETIME))
	self.titleNode:runAction(ActionUtil:fadeInU3D(self.titleNode, 3*FRAMETIME))
	self.closeBtn:runAction(ActionUtil:fadeInU3D(self.closeBtn, 3*FRAMETIME))
	-- self.beltAnim:runAction(ActionUtil:sequence{
	-- 	CCDelayTime:create(7*FRAMETIME),
	-- 	CCCallFunc:create(function()
	-- 		self.beltAnim:resume()
	-- 	end)
	-- })
	if self:checkNodeClear() then
		self:showNodeClearUI()
		safeRunCall(callback)
		return
	end
	setTimeOut(function()
		if self.isDisposed then return end
		self:beltShowAnim()
	end, 15*FRAMETIME)
	self.nodeQueue:foreach(function(index, node)
		if not node or node.isDisposed then return end
		node:runAction(ActionUtil:sequence{
			CCDelayTime:create(index*2*FRAMETIME),
			ActionUtil:spawn{
				ActionUtil:sequence{
					CCEaseSineOut:create(CCMoveBy:create(6*FRAMETIME, ccp(0, 233.56))),
					CCEaseSineInOut:create(CCMoveBy:create(4*FRAMETIME, ccp(0, -14.54))),
				},
				CCCallFunc:create(function()
					node:getChildByName("normalBg"):runAction(ActionUtil:sequence{
						ActionUtil:fadeInU3D(node:getChildByName("normalBg"), 2*FRAMETIME)
					})
					node:getChildByName("yellowBg"):runAction(ActionUtil:sequence{
						ActionUtil:fadeInU3D(node:getChildByName("yellowBg"), 2*FRAMETIME)
					})
					node:getChildByName("buttonNode"):runAction(ActionUtil:sequence{
						CCDelayTime:create(2*FRAMETIME),
						ActionUtil:fadeInU3D(node:getChildByName("buttonNode"), 2*FRAMETIME)
					})
					node:getChildByName("rewardNode"):runAction(ActionUtil:sequence{
						CCDelayTime:create(2*FRAMETIME),
						ActionUtil:fadeInU3D(node:getChildByName("rewardNode"), 2*FRAMETIME),
						CCCallFunc:create(function()
							if self.isDisposed then return end
							self:updateBtnBreath()
						end)
					})
					node:getChildByName("collectionNode"):runAction(ActionUtil:sequence{
						CCDelayTime:create(2*FRAMETIME),
						ActionUtil:fadeInU3D(node:getChildByName("collectionNode"), 2*FRAMETIME)
					})

					safeRunCall(callback)
					if index == self.nodeQueue:getSize() then
						self:dp(AMFEvent.new("GIFT_QUEUE_UPDATE_END"))
					end
				end),
			},
		})
	end)
end

function WaterfallPanel:flyNodeReward(node, rewardList, callback)
	local flyNum = 1
	local function afterFly()
		if self.isDisposed then return end
		if node.specialNum then
			flyNum = flyNum + 1
			local specialNumLabel = node.collectionLabel
			local startPos = specialNumLabel:getPositionInWorldSpace()
			local endPos = self.progressItemNode:getPositionInWorldSpace()
			self:doFlyCollectionAction(ccp(startPos.x-50, startPos.y), ccp(endPos.x+30, endPos.y+40), function()
				if self.isDisposed then return end
				safeRunCall(callback)
			end)
			node.collectionIcon:setVisible(false)
			node.collectionLabel:setVisible(false)
			setTimeOut(function()
				if self.isDisposed then return end
				self:sendCommand("playProgressBarAddAnim")
			end, 0.4)
		else
			safeRunCall(callback)
		end
	end

	-- local rewardList = {}
	-- for i = 1, 7 do
	-- 	table.insert(rewardList, {itemId = 2, num = 100})
	-- end

	local flyAnim = WaterfallWeakFlyAnim.Builder.new()
	:setTarget(node)
	:setRewards(rewardList)
	:setOffset(ccp(0, 40))
	:setEndCallback(function()
		printx(33, "flyNodeReward end")
		afterFly()
	end)
	:build()
end

function WaterfallPanel:flySpecialReward()
	
end

function WaterfallPanel:flyProgressReward(rewards, isFinal, callback)
	if #rewards > 1 then
		local image = self.progressBar:getRewardItemImage()
		printx(33, "flyProgressReward image", image and image.Frame)
		if image and image.Frame == "common/icon_256/icon_baoxiang_erji_256_01" then
			self.progressBar:setRewardItemImage({
				Atlas = "ui/common/common_icon_256.plist",
				Frame = "common/icon_256/icon_baoxiang_erji_256_02",
			})			
		else
			self.progressBar:setRewardItemImage({
				Atlas = "ui/common/common_icon_256.plist",
				Frame = "common/icon_256/icon_baoxiang_wuji_256_02"
			})	
		end
	end
	local flyAnim = WaterfallWeakFlyAnim.Builder.new()
	:setTarget(self.progressRewardNode)
	:setOffset(ccp(40, 20))
	:setRewards(rewards)
	:setEndCallback(callback)
	:build()
end

function WaterfallPanel:setProgressBarZero(progressInfo)
	self.progressBar:setPercentage(0)
	self.progressBar:setProgressText("0/"..tostring(progressInfo.endValue))
end

function WaterfallPanel:setProgressBarRewardList(info)
	local rewardList = info.rewardList or {}
	local isFinal = info.isFinal
	if #rewardList == 1 then
		local reward = rewardList[1]
		self.progressBar:setRewardItemId(reward.itemId)
		-- if not _G.amfBean("PropManager"):isInfiniteProp(reward.itemId) then
		-- 	self.progressBar:setRewardCountString(YH_REF_MAP.x .. tostring(reward.num))
		-- else
		-- 	self.progressBar:setRewardCountString(tostring(reward.num))
		-- end
		self.progressBar:setRewardCountString(YH_REF_MAP.x .. tostring(reward.num))
	else
		self.progressBar:setRewardItemImage({
			Atlas = "ui/common/common_icon_256.plist",
			Frame = isFinal and "common/icon_256/icon_baoxiang_wuji_256_01" or "common/icon_256/icon_baoxiang_erji_256_01",
		})
		self.progressBar:setRewardCountString("")
	end
end

function WaterfallPanel:playProgressBarAddAnim(progressInfo, callback)
	local endValue = progressInfo.endValue
	local curValue = math.clamp(progressInfo.curValue, 0, endValue)
	self.progressBar:setPercentageWithAnim(curValue/endValue, 1, function(per)
		if self.isDisposed then return end
		local v = math.floor(per * endValue)
		self.progressBar:setProgressText(tostring(v).."/"..tostring(endValue))
	end, function()
		if self.isDisposed then return end
		self.progressBar:setProgressText(tostring(curValue).."/"..tostring(endValue))
		safeRunCall(callback)
	end)
end

function WaterfallPanel:showProgressRewardTip(rewardList, needMoreNum, isFinal)
	local labelWidth
	if isFinal then
        if needMoreNum < 10 then
            labelWidth = 420
        elseif needMoreNum < 100 then
            labelWidth = 430
        else
            labelWidth = 450
        end
	else
		if needMoreNum < 10 then
			labelWidth = 390
		elseif needMoreNum < 100 then
			labelWidth = 410
		else
			labelWidth = 425
		end		
	end

	local label = MultiLabel:create(CCSizeMake(labelWidth, 0))
	label:setLineVerticalAlignment(kCCVerticalTextAlignmentCenter)
	label:setHorizontalAlignment(kCCTextAlignmentCenter)
	label:setVerticalAlignment(kCCVerticalTextAlignmentCenter)
	label:addTTFLabel({
		text = "还差"..(tostring(needMoreNum)),
		fontSize = 28,
		color = hex2ccc4("B2714AFF")
	})
	local icon = UICreateUtil:createSpriteFile("amf/activity/waterfallprogress/materials/specialIcon.png")
	icon:setScale(0.2)
	label:addNode({
		node = icon,
	})
	if isFinal then
		label:addTTFLabel({
			text = ", 即可获得宝藏大奖～",
			fontSize = 28,
			color = hex2ccc4("B2714AFF")
		})		
	else
		label:addTTFLabel({
			text = ", 即可获得本奖励～",
			fontSize = 28,
			color = hex2ccc4("B2714AFF")
		})
	end

	local layer = Layer:create()
	layer:addChild(label)
	layer:makeContentSizeContainChildren()
	local size = layer:getContentSize()
	layer:setContentSize(CCSizeMake(size.width-20, size.height-10))
	LayoutUtil:move(label:getLine(1).labels[2], 0, 2)
	local tip = UITip.Builder.new()
	:setOrdered()
	:setContent(layer, false)
	:setRewards(rewardList)
	:setTarget(self.progressRewardNode)
	:setAutoCloseTime(3)
	:build()
end

function WaterfallPanel:showProgressItemTip(rewardList)
	local label = MultiLabel:create(CCSizeMake(390, 0))
	label:setLineVerticalAlignment(kCCVerticalTextAlignmentCenter)
	label:setHorizontalAlignment(kCCTextAlignmentCenter)
	label:setVerticalAlignment(kCCVerticalTextAlignmentCenter)
	label:addTTFLabel({
		text = "积累",
		fontSize = 28,
		color = hex2ccc4("B2714AFF")
	})
	local icon = UICreateUtil:createSpriteFile("amf/activity/waterfallprogress/materials/specialIcon.png")
	icon:setScale(0.2)
	label:addNode({
		node = icon,
	})
	label:addTTFLabel({
		text = "，获得超多宝藏奖励~",
		fontSize = 28,
		color = hex2ccc4("B2714AFF")
	})
	local layer = Layer:create()
	layer:addChild(label)
	layer:makeContentSizeContainChildren()
	UITip.Builder.new()
	:setContent(layer, false)
	:setTarget(self.progressItemNode)
	:setAutoCloseTime(3)
	:build()
end

function WaterfallPanel:showGuideHand()
	if self.needHideGuideHand then return end
    local GuideHand = require "amf.middleware.ui.kit.animation.guide.GuideHand"
    local hand = GuideHand:createHandClick(0, 3, true)
	local frontNode = self.nodeQueue:getFront()
	if frontNode then
		local btn = frontNode:getChildByName("buttonNode")
		local pos = btn:getPositionInWorldSpace()
		self.ui:addChild(hand)
		hand:setPositionInWorldSpace(ccp(pos.x, pos.y))
		local layer = Layer:create()
		layer:setTouchHandler(function()
			if self.isDisposed then return end
			hand:removeFromParentAndCleanup(true)
			layer:removeFromParentAndCleanup(true)
		end, nil, function()
			return true
		end, false)
		btn:addChild(layer)
	end
	self.guideHand = hand
end

function WaterfallPanel:hideGuideHand()
	self.needHideGuideHand = true
	if self.guideHand then
		self.guideHand:removeFromParentAndCleanup(true)
		self.guideHand = nil
	end
end

--region 【app】抖音支付瀑布流礼包定制营销

function WaterfallPanel:setDyOfferUpdate(dyOfferInfo)
	self.dyOfferInfo = dyOfferInfo
	if self.isWaitingDyOffer then
		self:updateByDyPayNode()
	end
end

function WaterfallPanel:initOtherUI(showDyPayTag)
	if showDyPayTag then
		local uiData = force_require("amf.feature.localactivity.waterfallgift.view.uisource.WaterfallDouyinPayNode_UI")
		local faqBtn = UIBuilder:buildUI(uiData, self, "faqBtn")
		self.titleNode:addChild(faqBtn)
		faqBtn:setPositionXY(110, 20)
		self.helpBtn = faqBtn
		self:ad("GIFT_QUEUE_UPDATE_END", function()
			self:updateByDyPayNode()
		end)
		self.helpBtn:setTouchHandler(function ()
			local url = "https://ff.happyelements.com/mobile/page/topic.html?tid=6933117&app=1001&ct=1765872600&gohome=1"
			FAQ:openSheQuUrl(url)
		end)
	end
end

function WaterfallPanel:updateByDyPayNode()
	if self.isDisposed then return end
	if not self.dyOfferInfo then
		self.isWaitingDyOffer = true
		return
	end
	self.isWaitingDyOffer = false
	self.nodeQueue:foreach(function(idx, node)
		if not node.isFree and not node.dyMarkNode then
			local price = GoodsManager:getGoods(node.goodsId):getPrice()
			if self.dyOfferInfo.price == price then
				local WaterfallDyPaymentView = force_require "amf.feature.localactivity.waterfallgift.view.WaterfallDyPaymentView"
				local view = WaterfallDyPaymentView:create(node.goodsId, self.dyOfferInfo)
				node:addChild(view)
				view:setPositionXY(55, 0)
				node.dyMarkNode = view
				node.dyMarkNode.showIdx = idx
				node.btn:setVisible(false)

				view:setBuyBtnCallback(function()
					self:sendCommand("onBuyBtnTapped", node, node.nodeIdx)
				end)

				local mgr = _G.amfBean("WaterfallGiftProgressManager")
				local guideId = Meta.DyOfferGuideId["PRICE_ANI_"..tostring(price)]
				if mgr:hasGuideIndex(guideId) then
					view:appearWithSimpleAni(idx == 1)
				else
					mgr:addGuideIndex(guideId)
					view:runMarkNodeAppearAction(function()
						view:runParentHitAction(node)
					end)
					view:runBtnAppearAction(idx == 1)
				end

				mgr:dc("dy_pay", "label", self.dyOfferInfo.dyType, nil, nil, nil, {
					show_id = node.tracer and node.tracer:getShowId(),
					goods_id = node.goodsId,
					price = price,
					discounts = self.dyOfferInfo.discount,
					discounts_price = self.dyOfferInfo.finalPrice,
				})
			end
		elseif node.dyMarkNode and idx == 1 then
			if node.dyMarkNode.showIdx ~= 1 then
				node.dyMarkNode.showIdx = idx
				node.dyMarkNode:runBtnBreathAction()
			end
		end
	end)
end

function WaterfallPanel:doFlyCollectionAction(srcPos, targetPos, done)
    local function playEndVfx(endPos)
		if self.isDisposed then return end
        local anim = UICreateUtil:createSpine("amf/activity/waterfallprogress/spine/reward_vfx.skel")
        self.ui:addChild(anim)
        anim:setPosition(endPos)
        anim:setScale(0.6)
        anim:playOnceAndDispose("end")
    end

    local flyNum = 10
    local flyDownCount = 0
    local function callBack(endPos)
        flyDownCount = flyDownCount + 1

        if flyDownCount == 1 or flyDownCount == 5 or flyDownCount == 9 then
            playEndVfx(endPos)
        end

        if flyDownCount >= flyNum then
            safeRunCall(done)
        end
    end

    local function createBezierObject(startPos, endPos, time)
        local p1 = ccp((0.2+0.05*math.random(-2,2))*(endPos.x - startPos.x), (-0.2+0.05*math.random(-2,2))*(endPos.y - startPos.y))
        local p2 = ccp((0.8+0.05*math.random(-2,2))*(endPos.x - startPos.x), (-0.2+0.05*math.random(-2,2))*(endPos.y - startPos.y))

        local bezierConfig = ccBezierConfig:new()
        bezierConfig.controlPoint_1 = ccp(startPos.x +  p1.x, startPos.y +  p1.y)
        bezierConfig.controlPoint_2 = ccp(startPos.x +  p2.x, startPos.y +  p2.y)
        bezierConfig.endPosition = ccp(endPos.x,endPos.y)
        local object = CCEaseSineIn:create(CCBezierTo:create(time, bezierConfig))
        return object
    end

    local function flyCash(index)
        local cashIcon = UICreateUtil:createSpriteFile("amf/activity/waterfallprogress/materials/specialIcon.png")
        cashIcon:setScale(0)


        self.ui:addChild(cashIcon)
        local startPos = ccp(srcPos.x + 2 * math.random(-8, 8), srcPos.y + 2 * math.random(-8, 8))
        local startPos = self.ui:convertToNodeSpace(startPos)
        local endPos = self.ui:convertToNodeSpace(targetPos)
        cashIcon:setPosition(startPos)

        cashIcon:runAction(ActionUtil:sequence{
            ActionUtil:spawn{
                CCEaseBackOut:create(CCScaleTo:create(0.2, 0.3*0.7)),
                CCEaseSineIn:create(CCFadeIn:create(0.2)),
                CCEaseSineIn:create(CCMoveBy:create(0.3, ccp(0, 15))),
            },
            ActionUtil:spawn{
                createBezierObject(ccp(startPos.x, startPos.y + 15), endPos, 0.2 + index * 0.05),
                ActionUtil:sequence{
                    CCEaseSineOut:create(CCScaleTo:create(0.05 + index * 0.02, 0.4*0.7)),
                    CCEaseSineIn:create(CCScaleTo:create(0.15 + index * 0.03, 0.2*0.7)),
                },
            },
            CCCallFunc:create(function()
				if self.isDisposed then return end
                callBack(endPos)
                cashIcon:removeFromParentAndCleanup(true)
            end),
        })
    end

    for index = 1, flyNum do
        flyCash(index)
    end
end

return WaterfallPanel
