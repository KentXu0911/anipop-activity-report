local ReturnGiftStartPanelView = require "amf.feature.localactivity.returngift.view.ReturnGiftStartPanelView"
local Extra = require "amf.feature.localactivity.returngift.model.ReturnGiftExtra"
local Const = require "amf.feature.localactivity.returngift.config.ReturnGiftConst"
local ReturnGiftGoodsUIOperator = require "amf.feature.localactivity.returngift.view.ReturnGiftGoodsUIOperator"
local ReturnGiftActInfo = require "amf.feature.localactivity.returngift.util.ReturnGiftActInfo"
local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"

---@class ReturnGift2StartPanelView : ReturnGiftStartPanelView
local ReturnGift2StartPanelView = class("ReturnGift2StartPanelView", ReturnGiftStartPanelView)

function ReturnGift2StartPanelView:initSelfUI()
    ReturnGiftStartPanelView.initSelfUI(self)
    self:registerRewardingExtraUpdateEvent()
    self:initRewardBlocks()
    self:refreshRewardState()


end

function ReturnGift2StartPanelView:getModuleExtra()
    return self.delegate and self.delegate.moduleExtra or {}
end

function ReturnGift2StartPanelView:isRewarding()
    return Extra.isRewarding(self:getModuleExtra())
end

function ReturnGift2StartPanelView:onBuySuccess()
    self:setBoughtRewardingState()
    self:initRewardingLeftTime()
    ReturnGiftStartPanelView.onBuySuccess(self)
end

function ReturnGift2StartPanelView:setBoughtRewardingState()
    local moduleExtra = self:getModuleExtra()
    moduleExtra.status = Const.Status.REWARDING
    moduleExtra.state = Const.State.PACKAGE_2_REWARDING
    moduleExtra.packageType = Const.PackageType.PACKAGE_2

    local giftExtra = self.giftData and self.giftData.getExtraValue and Extra.parse(self.giftData:getExtraValue("moduleExtra")) or nil
    self:mergeRewardingExtra(moduleExtra, giftExtra)
    self:mergeRewardingExtra(moduleExtra, ReturnGiftActInfo:getExtra())
    self:refreshRewardState()
end

function ReturnGift2StartPanelView:mergeRewardingExtra(target, source)
    if not target or not source then return end
    local packageType = tonumber(source.packageType) or Extra.getPackageType(source)
    local status = tonumber(source.status) or 0
    local state = tonumber(source.state) or 0
    if packageType ~= Const.PackageType.PACKAGE_2
        and status ~= Const.Status.REWARDING
        and state ~= Const.State.PACKAGE_2_REWARDING then
        return
    end

    if source.rewardEndTs then target.rewardEndTs = source.rewardEndTs end
    if source.rewardNodes then target.rewardNodes = source.rewardNodes end
end

function ReturnGift2StartPanelView:initRewardingLeftTime()
    local endTime = Extra.getRewardEndTime(self:getModuleExtra())
    if endTime <= 0 then return end

    if self._tickId then
        TimerUtil.removeAlarm(self._tickId)
        self._tickId = nil
    end

    local remain = endTime - TimeKit:timeInSec()
    if remain > 0 then
        self._tickId = TimerUtil.addAlarm(function()
            if self.isDisposed then return end
            remain = remain - 1
            self:updateByTime(remain)
            if remain <= 0 then
                TimerUtil.removeAlarm(self._tickId)
                self._tickId = nil
                self:onCountDownEnd()
            end
        end, 1, 0)
        self:updateByTime(remain)
    else
        self:updateByTime(0)
        self:onCountDownEnd()
    end
end

function ReturnGift2StartPanelView:registerRewardingExtraUpdateEvent()
    if self._returnGiftRewardingExtraEvent then return end
    self._returnGiftRewardingExtraEvent = function(event)
        self:onRewardingExtraUpdate(event)
    end
    GiftEventCenter:register(GiftEvent.RETURN_GIFT_REWARDING_EXTRA_UPDATE, self._returnGiftRewardingExtraEvent)
end

function ReturnGift2StartPanelView:unregisterRewardingExtraUpdateEvent()
    if not self._returnGiftRewardingExtraEvent then return end
    GiftEventCenter:unregister(GiftEvent.RETURN_GIFT_REWARDING_EXTRA_UPDATE, self._returnGiftRewardingExtraEvent)
    self._returnGiftRewardingExtraEvent = nil
end

function ReturnGift2StartPanelView:onRewardingExtraUpdate(event)
    if self.isDisposed then return end
    local data = event and event:getData() or {}
    self:mergeRewardingExtra(self:getModuleExtra(), data.moduleExtra)
    self:initRewardingLeftTime()
    self:refreshRewardState()
end

function ReturnGift2StartPanelView:dispose()
    self:unregisterRewardingExtraUpdateEvent()
    ReturnGiftStartPanelView.dispose(self)
end

function ReturnGift2StartPanelView:refreshRewardState()
    local rewarding = self:isRewarding()
    if self.styleNode_1 then self.styleNode_1:setVisible(not rewarding) end
    if self.styleNode_2 then self.styleNode_2:setVisible(rewarding) end
    if rewarding then self:refreshRewardBlocks() end
end

function ReturnGift2StartPanelView:initRewardBlocks()
    if self.rewardBlocks then return end
    self.rewardBlocks = {}

    for index = 1, 3 do
        local block = self:findChildByName(self.styleNode_2, "blockNode_" .. tostring(index))
        if block then
            self.rewardBlocks[index] = {
                node = block,
                receivedNode = self["receivedNode_"..index] or self:findChildByName(block, "receivedNode") or self:findChildByName(block, "receivedNode_"..index),
                unreceivedNode = self["unreceivedNode_"..index] or self:findChildByName(block, "unreceivedNode") or self:findChildByName(block, "unreceivedNode_"..index),
                awardGroupIcon = self.awardGroupIcon or self:findChildByName(block, "awardGroupIcon"),
                timelabelText = self["timelabelText_"..index] or self:findChildByName(block, "timelabelText") or self:findChildByName(block, "timelabelText_"..index),
            }
            if block.setTouchHandler then
                block:setTouchHandler(function()
                    self:onRewardBlockTapped(index)
                end)
            end
        end
    end
end

function ReturnGift2StartPanelView:refreshRewardBlocks()
    local rewardNodes = Extra.getRewardNodes(self:getModuleExtra())
    self:updateRewardBlocksLayout(#rewardNodes)
    for index, block in ipairs(self.rewardBlocks or {}) do
        local rewardNode = rewardNodes[index]
        if block.node then block.node:setVisible(rewardNode ~= nil) end
        local alreadyGot = rewardNode and rewardNode.alreadyGot == true
        if block.receivedNode then block.receivedNode:setVisible(alreadyGot) end
        if block.unreceivedNode then block.unreceivedNode:setVisible(rewardNode ~= nil and not alreadyGot) end
        local reward = rewardNode and rewardNode.rewards and rewardNode.rewards[1]
        if block.awardGroupIcon then
            block.awardGroupIcon:setVisible(reward ~= nil)
            if reward then
                self:getGoodsUIOperator():setIconItem(block.awardGroupIcon, reward)
            end
        end
        if block.timelabelText and block.timelabelText.setString and reward then
            block.timelabelText:setString(self:getRewardTimeText(reward))
        elseif block.timelabelText and block.timelabelText.setString then
            block.timelabelText:setString("")
        end
    end
end

function ReturnGift2StartPanelView:updateRewardBlocksLayout(rewardCount)
    self:cacheRewardBlockOriginPos()
    if rewardCount == 2 then
        local pos1 = self.rewardBlockOriginPos and self.rewardBlockOriginPos[1]
        local pos2 = self.rewardBlockOriginPos and self.rewardBlockOriginPos[2]
        local pos3 = self.rewardBlockOriginPos and self.rewardBlockOriginPos[3]
        if pos1 and pos2 and pos3 then
            local offset = (pos3.x - pos2.x) / 2
            self:setRewardBlockPosition(1, pos1.x + offset, pos1.y)
            self:setRewardBlockPosition(2, pos2.x + offset, pos2.y)
        end
        return
    end

    self:restoreRewardBlockOriginPos()
end

function ReturnGift2StartPanelView:cacheRewardBlockOriginPos()
    if self.rewardBlockOriginPos then return end
    self.rewardBlockOriginPos = {}
    for index, block in ipairs(self.rewardBlocks or {}) do
        local node = block and block.node
        if node and node.getPositionX and node.getPositionY then
            self.rewardBlockOriginPos[index] = { x = node:getPositionX(), y = node:getPositionY() }
        end
    end
end

function ReturnGift2StartPanelView:restoreRewardBlockOriginPos()
    for index, pos in pairs(self.rewardBlockOriginPos or {}) do
        self:setRewardBlockPosition(index, pos.x, pos.y)
    end
end

function ReturnGift2StartPanelView:setRewardBlockPosition(index, x, y)
    local block = self.rewardBlocks and self.rewardBlocks[index]
    local node = block and block.node
    if not node or not x or not y then return end
    if node.setPositionXY then
        node:setPositionXY(x, y)
    else
        node:setPosition(ccp(x, y))
    end
end

function ReturnGift2StartPanelView:getRewardTimeText(reward)
    if not reward then return "" end
    return ReturnGiftGoodsUIOperator:getTimeItemText(reward)
end

function ReturnGift2StartPanelView:onRewardBlockTapped(index)
    if not self:isRewarding() then return end

    local rewardNodes = Extra.getRewardNodes(self:getModuleExtra())
    local rewardNode = rewardNodes[index]
    if not rewardNode or rewardNode.alreadyGot then return end
    if not rewardNode.rewards or #rewardNode.rewards == 0 then return end

    local rewardIndex = tonumber(rewardNode.index)
    if rewardIndex == nil then rewardIndex = index - 1 end
    if not self.delegate or not self.delegate.claimReward then return end

    self.delegate:claimReward(rewardIndex, function(rewards)
        if self.isDisposed then return end
        self:playClaimRewardFlyToBag(rewards, index, function()
            if self.isDisposed then return end
            self:refreshRewardState()
            self:removeSelfIfAllClaimed()
        end)
    end)
end

function ReturnGift2StartPanelView:playClaimRewardFlyToBag(rewards, blockIndex, finishCallback)
    local flyItems = self:getClaimRewardFlyItems(rewards, blockIndex)
    if not flyItems or #flyItems == 0 then
        safeRunCall(finishCallback)
        return
    end

    --小游戏飞动画特殊处理
    if EnvUtil:isMiniGame() then
        local flyNum = #flyItems
        for index, value in ipairs(flyItems) do
            setTimeOut(function()
                if self.isDisposed then return end
                local flyItem = table.clone(value)
                local flyContext = FlyItemContext.new(flyItem, ccp(360, 720))
                if index == flyNum then
                    flyContext:setFinishCallback(function()
                        safeRunCall(finishCallback)
                    end)
                end
                _G.amfTransaction(TransactionEvent.FLY_ITEMS, flyContext)
            end, (index - 1) * Const.FlyItemDealy)
        end
        return
    end

    local flyContext = FlyItemContext.new(flyItems, ccp(360, 720))
    flyContext:setFinishCallback(function()
        safeRunCall(finishCallback)
    end)
    _G.amfTransaction(TransactionEvent.FLY_ITEMS, flyContext)
end

function ReturnGift2StartPanelView:getClaimRewardFlyItems(rewards, blockIndex)
    local flyItems = {}
    local block = self.rewardBlocks and self.rewardBlocks[blockIndex]
    local sourceNode = block and (block.awardGroupIcon or block.node)
    for index, item in ipairs(rewards or {}) do
        local flyItem = table.clone(item)
        flyItem.fromPos = self:getFlyNodeCenterWorldPos(sourceNode)
        flyItem.shandowNum = Const.FlyItemShandowNum
        -- if delay and delay > 0 then flyItem.delay = delay end
        table.insert(flyItems, flyItem)
    end
    return flyItems
end

function ReturnGift2StartPanelView:getFlyNodeCenterWorldPos(node)
    if not node or not node.getGroupBounds then return nil end
    local bounds = node:getGroupBounds()
    if not bounds then return nil end
    return ccp(bounds.origin.x + bounds.size.width / 2, bounds.origin.y + bounds.size.height / 2)
end

function ReturnGift2StartPanelView:removeSelfIfAllClaimed()
    if Extra.hasUnclaimedReward(self:getModuleExtra()) then return end
    if self.delegate and self.delegate.onAllRewardsClaimed then
        self.delegate:onAllRewardsClaimed(self)
        return
    end
    self:removeSelf()
    if self.delegate and self.delegate.refreshStage then
        self.delegate:refreshStage(self.giftData and self.giftData:getStageType())
    end
end

function ReturnGift2StartPanelView:findChildByName(root, name)
    if not root or not name then return nil end
    if root.getName and root:getName() == name then return root end

    local children = root.getChildrenList and root:getChildrenList() or nil
    if children then
        for _, child in ipairs(children) do
            local target = self:findChildByName(child, name)
            if target then return target end
        end
    end
end

return ReturnGift2StartPanelView
