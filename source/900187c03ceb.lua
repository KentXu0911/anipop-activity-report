local ThirdPanelAVM = require "amf.middleware.ui.kit.panel.third.ThirdPanelAVM"

local EnterRankingPanelVM = class("EnterRankingPanelVM", ThirdPanelAVM)
local Builder = newBuilder(EnterRankingPanelVM)

function Builder:ctor()

end

function Builder:setRewards(rewards, createFunc)
    self.rewards = rewards
    self.createFunc = createFunc
    return self
end

function Builder:setNeedFly(isFly)
    self.isFly = isFly
    return self
end

function EnterRankingPanelVM:_createPanel(...)
    local RecordPanel = require_debug "amf.middleware.ui.kit.panel.third.EnterRankingPanel"
    return RecordPanel:create(EnterRankingPanelVM, ...)
end

function EnterRankingPanelVM:init(delegate)
    ThirdPanelAVM.init(self, delegate)
    self.rewards = self.delegate.rewards
	self.createFunc = self.delegate.createFunc
	self.isFly = self.delegate.isFly
end

function EnterRankingPanelVM:firstLoadCompleted()
    ThirdPanelAVM.firstLoadCompleted(self)
end

function EnterRankingPanelVM:close()
	if self.isDisposed then return end

	if self.isFly then
		self:flyFunc(function(  )
			if self.isDisposed then return end
			self:_close()
		end)
	else
	    self:_close()
	end
end

function EnterRankingPanelVM:flyFunc( callback )
	if self.isDisposed then return end
	local RewardFlyHelper = require 'amf.feature.localactivity.processgiftautopopup.RewardFlyHelper.lua'
	local rewardNum = math.min(#self.rewards,3)
	if rewardNum <= 0 then
		safeRunCall(callback)
		return
	end
	local needFlyNum = 0
	for i = 1,rewardNum,1 do
		local reward = self.rewards[i]
		if reward.doNotFly or not _G.amfBean("PropManager"):isPropNeedFly(reward.itemId) then
			reward.doNotFly = true
		else
			needFlyNum = needFlyNum+1
		end
	end

	if needFlyNum <= 0 then
		safeRunCall(callback)
		return
	end

	self:lock()
	local flyEndNum = 0
	local function innerFlyEndCall(  )
		flyEndNum = flyEndNum+1
		if flyEndNum == needFlyNum then
			self:unLock()
			safeRunCall(callback)
		end
	end

	for i = 1,rewardNum,1 do
		local startWorldPos = self:getPropWorldPosition(i)
		if startWorldPos then 
			local reward = self.rewards[i]
			if not reward.doNotFly and reward.flyFunc then
				reward.flyFunc(reward,startWorldPos,1,innerFlyEndCall)
			elseif not reward.doNotFly then
				RewardFlyHelper:rewardFlyFunc(false,reward,startWorldPos,nil,nil,innerFlyEndCall)
			end
		else 
			safeRunCall(innerFlyEndCall)
		end 
	end

	setTimeOut(function(  )
		if self.isDisposed then return end
		self:close()
	end,6)
end

function EnterRankingPanelVM:update(delegate)
    if type(delegate) ~= "table" then return end

    if delegate.textStruct then
        self:callViewFunc("setText", delegate.textStruct)
    end

    if delegate.bottomTextStruct then
        self:callViewFunc("setBottomText", delegate.bottomTextStruct, delegate.bottomTextAdjustY)
    end

    if delegate.rewards then
        self:callViewFunc("setRewards", delegate.rewards, delegate.createFunc)
    end

    self:callViewFunc("layout")
end

function EnterRankingPanelVM:test()
	local icon = Sprite:createWithSpriteFrameName("other/common/ui_com_hongdian")
	local label = {
		"收集",
		"<<node>>",
		"就可以获得限定动态头像框哦~",
		nodes = {icon}
	}

    local vm = EnterRankingPanelVM.Builder.new()
    :setTitle("恭喜进入排行榜")
    :setTopText(label)
    :setBottomText("前三名可得")
    :setRewards({
		{itemId = HeadFrameType.kKoiBlessing2022HeadFrame_3+60000, num = 1},
	})
	:setButtonsConfig(
		{
			params = {
				str = "去看看",
				widthMode = UIButtonConfig.Widths.kShort,
				colorMode = UIButtonConfig.ColorMode.green,
			},
			callback = function( event )
				printx(30,"打开排行榜",event.context)
			end
		}
	)
    :build()

    vm:popout()
end

return EnterRankingPanelVM
