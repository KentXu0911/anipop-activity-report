require 'amf.feature.localactivity.fixbirdnest.config.FixBirdNestConst'
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local FixBirdNestLog = require 'amf.feature.localactivity.fixbirdnest.FixBirdNestLog'
local FixBirdNestModel = require 'amf.feature.localactivity.fixbirdnest.model.FixBirdNestModel'
local FixBirdNestDC = require 'amf.feature.localactivity.fixbirdnest.dc.FixBirdNestDC'

local FixBirdNestManager = class("FixBirdNestManager")

function FixBirdNestManager:initialize()
	_G.amfEC:registerFeature(self)
    self.model = FixBirdNestModel:create()
	self.dc = FixBirdNestDC.new()
	self.dc:setMgr(self)
	self.actId = _G.FixBirdNestConst.ACT_ID
	ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
	PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
end

function FixBirdNestManager:onActActInfoUpdate(event)
	TimerUtil.addAlarm(function()
		self:setBeforeProgress()
	end, 0.1)
end

function FixBirdNestManager:isEnabled()
	if not self.model:isDataReady() then
		return false
	end
	return true
end

-- @override 是否在正式期内
function FixBirdNestManager:isInActMainTime()
	return self.model:isInActMainTime()
end
-- @override 是否在领奖期
function FixBirdNestManager:isInAwardTime()
	return self.model:isInAwardTime()
end

function FixBirdNestManager:hasRewards()
	if not self:isEnabled() then return end
	local hasGroup = self.model:isCanGetGroupReward() and not self.model:isGotGroupReward()
	local hasTaskReward = self.model:hasTaskReward()
	return hasGroup or hasTaskReward
end

function FixBirdNestManager:getTaskType()
	if _G.amfBean("UserStateManager"):isFMJ() then
		return _G.FixBirdNestConst.TaskType.TOP
	elseif _G.amfBean("UserStateManager"):isColorfulStarFull() then
		return _G.FixBirdNestConst.TaskType.SCORE
	else
		return _G.FixBirdNestConst.TaskType.COLOR
	end
end

-- 是否有引导标记
function FixBirdNestManager:hasGuideIndex( index)
    local guideInfo = self.model:getGuideInfo()
    for i,v in ipairs(guideInfo) do
    	if v == index then
    		return true
    	end
    end
    return false
end

function FixBirdNestManager:addGuideIndex( index )
    local guideInfo = self.model:getGuideInfo()
    table.insert(guideInfo, index)
    self.model:setGuideInfo(guideInfo)
	local SetActGuidFlag = require "amf.middleware.activity.http.SetActGuidFlag"
	SetActGuidFlag:post({
		actId = _G.FixBirdNestConst.ACT_ID,
		index = index
	})
end

function FixBirdNestManager:getActInfo()
	return _G.amfBean("ActivityMgr"):getActInfo(_G.FixBirdNestConst.ACT_ID)
end

-- 刷新接口
function FixBirdNestManager:updateTipView(needProgress)
	if needProgress == nil then
		needProgress = false
	end
	local function setIconInfo(hasReward)
		local actInfo = self:getActInfo()
		if not actInfo then return end
		actInfo.reward = hasReward
		if needProgress then
			local curTaskInfo = self.model:getCurTaskInfo()
			actInfo.progress = curTaskInfo.progress
			actInfo.maxProgress = curTaskInfo.target
		end
		ActivityEventCenter:dispatch(ActivityEvent.SET_ACT_INFO, actInfo)
	end
	if not self:isEnabled() then return end
	local hasReward = self:hasRewards()
	setIconInfo(hasReward)
end

--------------------关卡内--------------------------------
function FixBirdNestManager:isEnabledInLevel( ... )
    -- do return true end
	if not self:isEnabled() then
    	return false
    end
    -- 主活动期可用
    if not self:isInActMainTime() then
    	return false
    end
    return true
end

function FixBirdNestManager:isEnabledInLevel2()
    -- 框架已经处理了分数buff的情况，不再需要单独处理
    -- 为了行为树保留这个接口
    return self:isEnabledInLevel()
end

function FixBirdNestManager:canShowStartPanelLeftBottomView( runtime )
    if not self:isEnabledInLevel() then return false end
    if not runtime then return false end
    if LevelSceneFunc:isFullLevelLib(runtime.levelScene) then
        return false
    end

    if runtime.levelType == 2 then
        local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
        if userState == _G.UserStateConst.UserSegmentState.FMJ then
            local isTopLevel = runtime.levelId == _G.amfBean("LevelAreaManager"):getTopLevelId() and not _G.amfBean("LevelAreaManager"):hasPassedLevelEx(runtime.levelId)
			if isTopLevel then return true, 1 end
        elseif _G.amfBean("UserStateManager"):isColorfulStarFull() then
			-- 满彩，任意关都行
			return true, 3
		elseif not _G.amfBean("UserStateManager"):isColorfulStarFull() then
            --主线非全满。 补星。只能补彩星
            local scoreOfLevel = _G.amfBean("LevelAreaManager"):getUserScore(runtime.levelId)
            local oldStar = scoreOfLevel and scoreOfLevel.star > 0 and scoreOfLevel.star or 0
            local levelFullStar = 4 --主线关一定是彩星
            if oldStar < levelFullStar and levelFullStar == 4 then
                return true, 2
            end
        end
    end

    return false
end

function FixBirdNestManager:getLifeNum()
	-- 获取当前生命
	return self.model:getLifeNum()
end

function FixBirdNestManager:getRestProgress()
	local curTaskInfo = self.model:getRealCurTaskInfo()
	return curTaskInfo.target - curTaskInfo.progress
end

function FixBirdNestManager:getTaskId()
	local curTaskInfo = self.model:getRealCurTaskInfo()
	return curTaskInfo.taskId
end

function FixBirdNestManager:getUserCurProgress()
	local curTaskInfo = self.model:getRealCurTaskInfo()
	return curTaskInfo.progress or 0
end

function FixBirdNestManager:isAllTaskFinish()
	return self.model.isAllTaskFinish and self.model:isAllTaskFinish()
end

function FixBirdNestManager:getCurAvailableBuffAndEndTime()
    local scoreBuffRate = 0.3
    local buffEndTime = math.floor(tonumber(self.model:getScoreBuffExpireTime()) / 1000) or 0
    -- local buffEndTime = TimeKit:timeInSec() + 3600
    return scoreBuffRate, buffEndTime
end

function FixBirdNestManager:getSlpBottomData(runtime)
    if not runtime then
        return
    end

    if not self:canShowStartPanelLeftBottomView(runtime) then
        return
    end

    local taskInfo = self.model:getRealCurTaskInfo()
	if not taskInfo then return end
	local lifeNum = self.model:getLifeNum()

    if taskInfo.progress == taskInfo.target then
		local taskCount = self.model:getTaskCount()
		local taskId = math.min(taskInfo.taskId + 1,taskCount)
		taskInfo = self.model:getTaskInfoByIndex(taskId)
		lifeNum = 3
	end

    local isAllFinish = self.model:isAllTaskFinish()
    local data = {
        progress = taskInfo.progress,
		target = taskInfo.target,
        lifeNum = isAllFinish and 3 or lifeNum,
        isAllFinish = isAllFinish,
    }
    -- local data = {
    --     progress = 1,
    --     target = 3,
    --     lifeNum = 2,
    --     isAllFinish = false
    -- }
    -- printx(15,"===FixBirdNestManager:getSlpBottomData===",tts(data))

    return data
end

function FixBirdNestManager:getPlpBottomData(runtime)
    if not runtime then
        return
    end
    -- 确认一下没触发活动能走到这吗
    -- 确认了，必须走到活动框架过关
    if not self:isEnabledInLevel() then
        return
    end
    -- printx(15,"self.canShowBottom",self.canShowBottom)
    if not self.canShowBottom then return end
	-- 是否上次就已经满了，那就不展示了
	if self.alreadyAllFinish then return end
	self.canShowBottom = false

	local recordInfo = table.clone(self.model:getRealCurTaskInfo())
	-- UError("recordInfo",tts(recordInfo))
	local curTaskInfo
	if recordInfo.progress == 0 then
		-- 成功过关了progress=0说明跨到下一个task了，往回退一个做展示
		local nowTask = recordInfo.taskId
		curTaskInfo = self.model:getTaskInfoByIndex(nowTask - 1)
	else
		curTaskInfo = recordInfo
	end
    
	local taskId = curTaskInfo.taskId
	curTaskInfo.progress = curTaskInfo.progress
	local progress = curTaskInfo.progress
	local target = curTaskInfo.target
	-- if progress >= target then
	-- 	curTaskInfo.showFinished = true
	-- end
	-- UError("===========",tts(curTaskInfo))
    local userState = self:getTaskType()
	local count = target - progress
	local resultStr = "修复鸟窝"..taskId.."："
	if userState == _G.FixBirdNestConst.TaskType.TOP then   -- 非满级
		resultStr = resultStr .."再完成" .. count .. "关可领取小鸟的谢礼~"
	elseif userState == _G.FixBirdNestConst.TaskType.COLOR then  -- 非满彩
		resultStr = resultStr.."再成功补彩星" .. count .. "关可获得奖励~"
	else
		resultStr = resultStr.."再成功刷分"..count.."关可获得奖励~"
	end
	if self.model:isAllTaskFinish() then
		resultStr = "恭喜您修复了全部鸟窝，快去领奖吧！"
	elseif progress == target then
		resultStr = "成功修复第"..taskId.."座鸟窝，快去领奖吧！"
	end
    local lifeNum = self.model:getRecord("lastLifeNum") or self.model:getLifeNum()
	lifeNum = math.clamp(lifeNum,1,3)

    local data = {
        mainEndTime = self.model:getMainEndTime(),
        curTaskInfo = curTaskInfo,
        proTotal = self.model:getTotalLevelByTaskId(taskId) - target + progress,
        subTitleStr = resultStr,
        lifeNum = lifeNum,
        userState = self:getTaskType(),
        getTotalLevelByTaskId = function(taskId)
            return self.model:getTotalLevelByTaskId(taskId)
        end,
        getTaskInfoByIndex = function(taskId)
            return self.model:getTaskInfoByIndex(taskId)
        end,
        isFinishedTask = function(taskId)
            return self.model:isFinishedTask(taskId)
        end,
        getRewardIcon = function(reward, needNum)
			local reward = table.clone(reward)
			reward.needNum = needNum
            return GameItemCreator:getPropIcon(reward)
        end,
        isAllFinish = self.model:isAllTaskFinish(),
    }

    return data
end

function FixBirdNestManager:onActDcStageCommon(evt)
    if not self:isEnabledInLevel() then return end
    local dcInfo = evt:getData()
    if not dcInfo then return end
    if dcInfo.sub_category == "start_show" then
	    local is_shed_tips = 0
	    local lifeNum = self.model:getLifeNum()
	    local curTaskInfo = self.model:getCurTaskInfo()

	    if lifeNum == 1 and (curTaskInfo.target - curTaskInfo.progress == 1) then
	    	is_shed_tips = 1
		end
		dcInfo.is_shed_tips = is_shed_tips
	elseif dcInfo.sub_category == "start_click" or dcInfo.sub_category == "pass_click" then
		dcInfo.buildshed = self:getDcBuildShed()
	end
end

function FixBirdNestManager:getDcBuildShed()
	local taskInfo = self.model:getCurTaskInfo()
	if not taskInfo then return end
	local tb = {
		live_num = self.model:getLifeNum(),
	    live_round = math.floor(self.model:getLostLives() / self.model:getMaxLife()),
	    task = taskInfo.progress .. "_".. taskInfo.target
	}
	local ret = mime.b64(table.serialize(tb))
	return ret
end


---以下都是出关的接口，关卡内不维护，我直接粘过来了-------
function FixBirdNestManager:recordLastData(curTaskInfo)
	self.model:saveRecord("lastTaskId", curTaskInfo.taskId)
	self.model:saveRecord("lastLifeNum", self.model:getLifeNum())
	self.model:saveRecord("lastTarget", curTaskInfo.target)
	self.model:saveRecord("lastProgress", curTaskInfo.progress)
end

function FixBirdNestManager:onPassLevel(levelContext)
	if not levelContext then return end
	self.needRelife = false
	self.pass_playId = levelContext.playId
	-- 是否可以收集，关卡内发出来的
	self.canShowBottom = levelContext.isPass
	self.alreadyAllFinish = false
	-- -- 所有任务完成就不处理
	if self.model:isAllTaskFinish() then
		self.alreadyAllFinish = true
		return
	end
	local lastCurTask = self.model:getCurTaskInfo()
	lastCurTask.showFinished = true
	self.model:saveRecord("curTaskInLevel", lastCurTask)
	self.levelPassed = true
	local curTaskInfo = self.model:getRealCurTaskInfo()
	local progress = curTaskInfo.progress
	local targetProgress = progress + 1
	local newTaskInfo = curTaskInfo
	newTaskInfo.progress = targetProgress
	if targetProgress >= curTaskInfo.target then
		local curLife = self.model:getLifeNum()
		if curLife < self.model:getMaxLife() then
			self.needRelife = true
		end
		self.model:setLifeNum(self.model:getMaxLife())
		self.model:resetCurTask(newTaskInfo)
		self.model:addFinishedTasks(1)
		self:tryGetMedal()
		self.dc:dcTaskSuccess(curTaskInfo.taskId)
	else
		self.model:resetCurTask(newTaskInfo)
	end
	self:recordLastData(newTaskInfo)
	self.model:saveRecord("lastProgress", progress)
	self:setBeforeProgress()
end

function FixBirdNestManager:onFailLevel(levelContext)
	if not levelContext then return end
	self.canShowBottom = false
	self.needRelife = false
	-- 所有任务完成就不处理
	if self.model:isAllTaskFinish() then
		return
	end
	self.levelFailed = true
	local curTaskInfo = self.model:getRealCurTaskInfo()
	self:recordLastData(curTaskInfo)
	if curTaskInfo.progress == 0 then
		return
	end
	self.model:addLifeNum(-1)
	self.model:addLostLives(1)
	-- 如果没命了要重置
	if self.model:getLifeNum() <= 0 then
		self.model:setLifeNum(self.model:getMaxLife())
		local newTaskInfo = curTaskInfo
		newTaskInfo.progress = 0
		self.model:resetCurTask(newTaskInfo)
		self.failedTask = true
	end
	if levelContext.failReason == "retry" then
		self:tryUpdateIcon()
	end
end

function FixBirdNestManager:tryGetMedal()
	if not self:isEnabled() then return end
	local medalId = self:getMedalId()
	if medalId == 3 then return end
	local medalTaskInfo = self.model:getMedalInfo(medalId + 1)
	if self.model:getFinishedTasks() >= medalTaskInfo.condition then
		self.model:addMedalId(1)
		local rewards = medalTaskInfo.rewards.list
		_G.GainPropData:create()
		  :setFeature(_G.FixBirdNestConst.DC_FEATURE)
		  :setSource("piont_reward")
		  :setProps(rewards)
		  :execute()
		local itemId = rewards and rewards[1] and rewards[1].itemId
		self.dc:dcMedalReward(itemId)
	end
end

function FixBirdNestManager:onActBeforeStartLevel(event)
	local data = event.data
	if not data then return end
	if data.levelType ~= 2 then return end
	if LevelSceneFunc:isFullLevelLib(data.levelScene) then return false end
	if not self:isEnabledInLevel() then return end
	self:tryUpdateIcon()
end

function FixBirdNestManager:isSupportShare()
	if EnvUtil:isWindows() then
		return true
	end
	if EnvUtil:isUnionMiniGame() then
		return false
	end
	if EnvUtil:isMiniGame() then
		return true
	end
	return false
end

function FixBirdNestManager.getWXMiniShareImg(target, shareParam, callback)
	local imgPath = "fixbirdnest_share.jpg"
	safeRunCall(callback, imgPath)
end

function FixBirdNestManager:setBeforeProgress()
	local icon = _G.amfBean("IconManager"):getIconByIconKey(tostring(_G.FixBirdNestConst.ACT_ID))
	if icon and isSafeCocosObj(icon) and icon.setBeforeProgress then
		icon:setBeforeProgress()
	end
end

function FixBirdNestManager:tryUpdateIcon()
	if (self.model:getRecord("lastLifeNum") or -1) <= 0 then
		return
	end
	if self.levelPassed or self.levelFailed then
		local context = {
			lastTaskId = self.model:getRecord("lastTaskId") or -1,
			lastLifeNum = self.model:getRecord("lastLifeNum") or 0,
			lastTarget = self.model:getRecord("lastTarget") or 0,
			lastProgress = self.model:getRecord("lastProgress") or 0,
			failed = self.failedTask ,
			needRelife = self.needRelife,
			levelPassed = self.levelPassed,
		}
		local icon = _G.amfBean("IconManager"):getIconByIconKey(tostring(_G.FixBirdNestConst.ACT_ID))
		TimerUtil.addAlarm(function()
			if icon and isSafeCocosObj(icon) then
				self:setBeforeProgress()
				icon:afterChange(context)
			end
		end, 1)

		self.levelPassed  = false
		self.levelFailed  = false
	else
		--TimerUtil.addAlarm(function()
		--	local icon = getIcon()
		--	if icon and isSafeCocosObj(icon) then
		--		--icon:checkTip()
		--	end
		--end, 1)
	end
	self.failedTask = false
end

function FixBirdNestManager:onActEnterMainScene(evt)
	local data = evt:getData()
	if data and data.firstEnter then
		return
	end
	self:tryUpdateIcon()
end

-------------------关卡内over-----------------------------

function FixBirdNestManager:popEnoughPanel(callback)
	local SecondPanelAVM = require "amf.middleware.ui.kit.panel.second.SecondPanelAVM"
	local rewards = {
		{
			itemId = 0, 
			num = 1,
			hideNum = true
		}
	}

    local textStruct = LabelStruct.new()
    textStruct:setText("感谢您帮助无家可归的小鸟重筑温暖巢穴，这是来自森林的谢礼！")
    textStruct:setLineSpace(10)
    textStruct:setHorizontalAlignment(kCCTextAlignmentCenter)

	local vm
    vm = SecondPanelAVM.Builder.new()
        :setTitle("鸟窝修复完成！")
        :setTextStruct(textStruct)
        :setFly(false)
        :setRewards(rewards, function(reward)
			local box = AMFCompHelper:createBoxFen()
			-- box.customOffX = -5
			-- box.customOffY = -5
			return box
		end)
        :setButtonsConfig({
			{
                str = "去领奖",
				widthMode = UIButtonConfig.Widths.kShort,
				colorMode = UIButtonConfig.ColorMode.green,
                touchFunc = function ( btn )
                    _G.amfBean("AutoPopupMgr"):resetPopup()
                    self:openMainActivity(nil,{fromStage4 = true},true)
                    if vm and not vm.isDisposed then
                        vm:onCloseBtnTapped()
                    end
                end
            },
        })
        :setCloseCallback(function()
			safeRunCall(callback)
        end)
        :build()
	self.model:saveRecord("hasPopEnoughPanel", true)
    vm:popout()
	return vm
end

function FixBirdNestManager:getNameMedalEndTime( medalId )
	-- 三个勋章的到期时间一致，默认用第一个1
	medalId = medalId or NameMedalId.kFixBirdNest_2_1
	local endTimeMs = _G.amfBean("PropManager"):getDecoEndTimeMs(medalId)
	if endTimeMs <= 0 then
		return tonumber(self.model:getMainEndTime())
	end
	return endTimeMs
end

function FixBirdNestManager:getMedalId()
	return self.model:getMedalId()
end

function FixBirdNestManager:getMedalInfo( medalId )
	return self.model:getMedalInfo(medalId)
end

function FixBirdNestManager:getFinishedTasks()
	return self.model:getFinishedTasks()
end

-- 说明面板
function FixBirdNestManager:showHelpView(closeCallback, params)
	params = params or {}
	local UserStateManager = _G.amfBean("UserStateManager")
	local isFMJ = UserStateManager:isFMJ()
	local panelPath
	if isFMJ then
		panelPath = 'amf.feature.localactivity.fixbirdnest.view.panel.DescNotFullPanel'
	else
		panelPath = 'amf.feature.localactivity.fixbirdnest.view.panel.DescFullPanel'
	end
	local DescPanelVM = require 'amf.feature.localactivity.fixbirdnest.view.vm.DescPanelVM'
	local vm = DescPanelVM.Builder.new()
		:setCloseCallback(closeCallback)
		:setDontAni(params.dontAni)
		:setPanelPath(panelPath)
		:build()
	vm:popout()
	return vm
end

function FixBirdNestManager:popGiftPanel( closeCallback, userClick )
	self.model:saveRecord("GiftPanel", true)
	local GiftPanel = require_debug("amf.feature.localactivity.fixbirdnest.view.vm.GiftPanelVM")
	local vm = GiftPanel.Builder.new()
	:setCloseCallback(closeCallback)
	:setUserClick(userClick)
	:setGoodsIds(self.model:getGoodsList())
	:setPayTagId(self.model:getPayTagId())
	:setManager(self)
	:setBDailyBought(self.model:isDailyBought())
	:build()

	vm:popout()
	return vm
end

function FixBirdNestManager:getCurSaledNum(  )
    local C = self.model:getConfigByName("rewardPkgIncrFuncC") or 100
    local Y = self.model:getConfigByName("rewardPkgIncrFuncY") or 8234590
    -- printx(16,"C Y",C,Y)

    local beginTime = self.model:getMainBeginTime()
    local endTime = self.model:getMainEndTime()

    local nowTime = TimeKit:timeInSec()


    local a = 1/10000000
    local x = math.floor((nowTime - beginTime) / 5 )
    local c = C



    local y = 1/3 * a * math.pow(x,3) + 1/2 * a * math.pow(x,2)


    local x0 = math.floor((endTime - beginTime) / 5 )
    local y0 = 1/3 * a * math.pow(x0,3) + 1/2 * a * math.pow(x0,2)

    y = Y / y0 * y + C


    return math.ceil(y)
end

function FixBirdNestManager:formatSaledNum( num )
    num = num or self:getCurSaledNum()
    if num > 10000 then
        return math.floor(num/10000) .. "万"
    else
        return tostring(num)
    end
end

function FixBirdNestManager:checkGiftPanel()
	if not self.model:getHasGift() then
		return false
	end
	if self:ignoreForTopLevelPlayer() then return false end
	-- body
	-- printx(16,"checkGiftPanel",self.defaultMap:getDay("GiftPanel",false) )
	if not self:isInActMainTime() then return false end

	if self:skipAutoPopup() then return false end

	if self.model:getRecord("GiftPanel", true) then
		return false
	end

	if self:checkEnoughPanel() then
		return false
	end

	return true
end

-- 满足条件的人屏蔽所有强弹
function FixBirdNestManager:skipAutoPopup(  )
	-- local inGroup = MaintenanceManager:getInstance():isEnabledInGroup("bird_riseup2", "G1_activelimit")
    local inPay = self.model:getPayTagId() <= 2
    local inLiveness = self.model:getLivenessTagId() <= 4
    return inPay and inLiveness
end

function FixBirdNestManager:checkEnoughPanel( ... )
	-- body
	-- printx(16,"checkEnoughPanel",self:isEnabled())
	if self:ignoreForTopLevelPlayer() then return false end
    if not self:isEnabled() then return false end

	if not self:isInActMainTime() then return false end

	if self:skipAutoPopup() then return false end

    local round = self.model:getRound()
    local curTaskInfo = self.model:getCurTaskInfo()
	-- printx(16,"checkEnoughPanel",round,curTaskInfo.progress , curTaskInfo.target , curTaskInfo.taskId)

    if round == 1 and curTaskInfo.progress < curTaskInfo.target and curTaskInfo.taskId == 1 then
    	return false
    end

    local taskInfo = self.model:getTaskInfoByIndex(1)
	-- printx(16,"checkEnoughPanel",tts(taskInfo))

    if taskInfo.reward then
    	return false
    end
	-- printx(16,"checkEnoughPanel",self.defaultMap:get("hasPopEnoughPanel",false))
    if self.model:getRecord("hasPopEnoughPanel") then
    	return false
    end

    return true
end

-- R1规则强弹主面板屏蔽
function FixBirdNestManager:checkPopMainPanel(  )
	if self:ignoreForTopLevelPlayer() then return false end
	if self:skipAutoPopup() then return false end
	return true
end

-- 在新关开启的指定时间内（暂定4小时），玩家主线关满星前，闯头部新关不触发关卡内结算面板点叉的场景4强弹
function FixBirdNestManager:ignoreForTopLevelPlayer()
    local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
    if userState == _G.UserStateConst.UserSegmentState.MHZC  then
        return false
    end

    if not _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then 
        return false
    end
    
    return true
end

---------------------------------- CUSTOM_GAIN ----------------------------------

function FixBirdNestManager:_onCustomGain(event)
    local reward = event:getData()
    if reward.itemId == _G.FixBirdNestConst.SCORE_BUFF_ID then
        local curTime = TimeKit:time()
        if tonumber(self.model:getScoreBuffExpireTime()) == 0 or
                curTime >= tonumber(self.model:getScoreBuffExpireTime()) then
            self.model:setScoreBuffExpireTime(curTime)
        end
        self.model:addScoreBuffExpireTime(60 * 1000 * reward.num)
    end
end

return FixBirdNestManager