local deferred = require "amf.script.sugar.deferred"
-- local MarkConst = require "amf.feature.dailyreward.mark.config.MarkConst"

local FriendRecommendManager = class("FriendRecommendManager")

function FriendRecommendManager:ctor()
    self._friendManager = nil
	self._levelAreaManager = nil
	self._userEnergyManager = nil
	self._autoPopupMgr = nil

	self._model = nil
end

function FriendRecommendManager:setFriendManager(mgr)
    self._friendManager = mgr
end

function FriendRecommendManager:setLevelAreaManager(mgr)
	self._levelAreaManager = mgr
end

function FriendRecommendManager:setUserEnergyManager(mgr)
	self._userEnergyManager = mgr
end

function FriendRecommendManager:setAutoPopupMgr(mgr)
	self._autoPopupMgr = mgr
end

function FriendRecommendManager:initialize()
    self._model = require("amf.feature.friend.module.friendrecommend.model.FriendRecommendModel"):create()
	_G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
end

function FriendRecommendManager:shouldAskRecommendInfo()
	local curEnergy = self._userEnergyManager:getEnergy() or 30
	if curEnergy > 25 then 
		return false
	end

	if not self._friendManager:isUnlocked() then 
		return false 
	end

	local nowTime = TimeKit:time()
	-- 玩家好友数≤20；
	local friendCount = self._friendManager:getFriendCount()
	if friendCount >= 200 then 
		return false 
	end

	local timeInterval3Day = 3 * 24 * 60 * 60 * 1000 --3天
	local timeInterval7Day = 7 * 24 * 60 * 60 * 1000 --7天

	local lastGetBottleTime = self._model:getLastReceiveFreeGiftTime() or 0
	-- 20<玩家好友数<200，且近七天内未收到好友赠送精力瓶。
	if friendCount > 20 and lastGetBottleTime and nowTime - lastGetBottleTime < timeInterval7Day then 
		return false
	elseif friendCount <= 20 and lastGetBottleTime and nowTime - lastGetBottleTime < timeInterval3Day then 
		return false
	end

	local lastRecommendTime = self._model:getLastRecommendTime() or 0
	-- 每隔三天
	if friendCount <= 20 and lastRecommendTime and type(lastRecommendTime) == "number" and nowTime - lastRecommendTime < timeInterval3Day then 
		return false
	elseif friendCount > 20 and lastRecommendTime and type(lastRecommendTime) == "number" and nowTime - lastRecommendTime < timeInterval7Day then 
		return false
	end

	return true
end

function FriendRecommendManager:requestRecommandInfo()
	local promise = deferred.new()

	self._model:requestRecommendFriendsWithLimit():next(function(response)
		local data = response:getData() or {}
		if not data.success then promise:reject() return end
		if not data.users or #data.users <= 0 then promise:reject() return end

		local friendsInfo = self:getFriendsInfo(data.users, data.profiles)

		promise:resolve(friendsInfo)
	end, function(response)
		if not response:isCancel() then 
			CommonTip:showErrorTip(response)
		end
		promise:reject()
	end)

	return promise
end

function FriendRecommendManager:requestAccept(uidsInfo)
	local promise = deferred.new()

	self._model:requestAcceptRecommendAndReward({
		mesUids = uidsInfo
	}):next(function(response)
		local data = response:getData() or {}
		if data.rewards and type(data.rewards) == "table" then
			local rewards = table.clone(data.rewards)
			GainPropData:create()
				:setFeature(DcFeatureType.kFriend)
				:setSource(DcSourceType.kRecommendFriendAccept)
				:setProps(rewards)
				:execute()
		end
		promise:resolve(data.rewards or {})
	end, function(response)
		if not response:isCancel() then 
			CommonTip:showErrorTip(response)
		end
		promise:reject()
	end)

	return promise
end

-- just test
-- function FriendRecommendManager:onActEnterMainScene(data)
-- 	self:openFriendRecommendPanel()
-- end

function FriendRecommendManager:onActTestButtonReady(data)
	addGlobalTestButton("尝试推荐好友", function()
		self:tryOpenFriendRecommendPanel()
		return nil, true
	end, {
		TestButtonConst.Tags.ACTIVITY,
	})
end

function FriendRecommendManager:onActEnterStage4(data)
	if not self:shouldAskRecommendInfo() then
		return 
	end

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.LUCKY_ENERGY_BOTTLE)
    end

	local asyncFriendInfo
    local creator = function()
		self:tryOpenFriendRecommendPanel(2):next(onHandleOver, onHandleOver)
    end

	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.LUCKY_ENERGY_BOTTLE, creator)
end

function FriendRecommendManager:openFriendRecommendPanel(friendInfo)
	local promise = deferred.new()

	local FriendRecommendPanelVM = require 'amf.feature.friend.module.friendrecommend.view.panel.FriendRecommendPanelVM'
	local panelvm = FriendRecommendPanelVM.Builder.new()
		:setFriendInfo(friendInfo)
		:setDefaultSelected(true)
		:setCloseCallback(function() 
			promise:resolve() 
		end)
		:setLoadResFailCallback(function() 
			promise:reject() 
		end)
		:build()

	panelvm:popout()

	return promise
end

function FriendRecommendManager:tryOpenFriendRecommendPanel(timeoutLimit)
	local promise = deferred.new()

	local bHandled = false

	if timeoutLimit then
		setTimeOut(function()
			if bHandled then return end
			bHandled = true
			promise:reject()
		end, timeoutLimit or 2)
	end

	self:requestRecommandInfo():next(function(friendInfo)
		if bHandled then return end
		bHandled = true
		self:openFriendRecommendPanel(friendInfo):next(function()
			promise:resolve()
		end, function()
			promise:reject()
		end)
	end, function()
		if bHandled then return end
		promise:reject()
	end)

	return promise
end

function FriendRecommendManager:getFriendsInfo(users, profiles)
	local friendsInfo = {}
	local profilesKV = {}
	if profiles then 
		for i,v in ipairs(profiles) do
			profilesKV[v.uid] = v
		end
	end

	for i,v in ipairs(users) do
		local info = {}
		info.uid = v.uid or "12345"
		info.topLevelId = v.topLevelId or 1
		info.hideStar = v.hideStar or 0
		info.star = v.star or 0
		info.enableNewFourStar = v.enableNewFourStar or false
		info.fourStarCount = v.fourStarCount or 0

		info.bGetReward = false --是否领奖

		local profile = profilesKV[v.uid]
		if profile then 
			info.name = profile.name or "消消乐玩家"
			info.headUrl = profile.headUrl or i
			info.sex = profile.gender or 0
			info.profile = profile
		else
			info.name = "消消乐玩家"
			info.headUrl = i
			info.sex = 0
		end
		table.insert(friendsInfo, info)
	end

	return friendsInfo
end

return FriendRecommendManager
