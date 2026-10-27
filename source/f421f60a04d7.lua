local AsyncRunner = require "amf.script.sugar.AsyncRunner"
local ProgressBar = require "amf.middleware.ui.kit.component.ProgressBar"

local MusicMasterPopMudule = class('MusicMasterPopMudule')

function MusicMasterPopMudule:create(MusicMasterManager)
    local instance = MusicMasterPopMudule.new()
    instance:init(MusicMasterManager)
    return instance
end

function MusicMasterPopMudule:init(MusicMasterManager)
    self.mgr = MusicMasterManager
end

-- 在新关开启的指定时间内（暂定4小时），玩家主线关满星前，闯头部新关不触发关卡内结算面板点叉的场景4强弹
function MusicMasterPopMudule:ignoreForTopLevelPlayer()
    local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
    if userState == _G.UserStateConst.UserLevelState.MHZC then
        return false
    end

    local topLevelId = _G.getTopLevelId()
    if not _G.amfBean("LevelUnLockManager"):isTopNewMainLevel(topLevelId) then 
        return false
    end

    if not _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then 
        return false
    end
    
    return true
end

function MusicMasterPopMudule:checkCurTimeCanPop()
    return not self:ignoreForTopLevelPlayer()
end

function MusicMasterPopMudule:checkPopAct()
	return self:checkCanPopStage4() == true
end

function MusicMasterPopMudule:checkCanPopStage4()
	--场景4强弹主面板，每期一次
	if not self.mgr:isEnabledAndResReady() then return end
	if not self:checkCurTimeCanPop() then return end

    local model = self.mgr:getModel()
    local mainEndTime = model:getMainEndTime()
    local hasEntered = (tonumber(mainEndTime) or 0) > 0
        and model:getValue("inLevelCardParticipatedEndTime") == mainEndTime
    if not hasEntered
        and _G.amfBean("ActivityParticipationMgr"):shouldReduceAutoPopup(self.mgr:getConst().ACT_ID) then
        return false
    end

	local bHadGuide = self.mgr:getModel():checkGuide( self.mgr:getConst().GuideIds.kPopPrePanel )
	if not bHadGuide then
		return true
	end
	return false
end

function MusicMasterPopMudule:doPopStage4( endCall )
	--场景4强弹面板
	if self:checkCanPopStage4() then
        self.mgr:getModel():setGuideIndex( self.mgr:getConst().GuideIds.kPopPrePanel )
		self:popMainPanel( endCall, {
			consumeV2NewOnOpen = true,
		})--from='popoup_scene4'
	else
		safeRunCall(endCall)
	end
end

function MusicMasterPopMudule:checkCanPopInLevel()
	--过关陈涛版强弹 有奖励可领取时
	if not self.mgr:isEnabledAndResReady() then return end
	if not self:checkCurTimeCanPop() then return end

	if self.mgr:hasRewardsInMainTime() then
		return true
	end
	return false
end

function MusicMasterPopMudule:doPopInLevel( endCall, UBFPopDelegate )
	--过关强弹面板
	if self:checkCanPopInLevel() then
		self:popMainPanel( endCall, {
			from = 'popout_scene4',
			consumeV2NewOnOpen = true,
		}, UBFPopDelegate)
	else
		safeRunCall(endCall)
	end
end
----

function MusicMasterPopMudule:popMainPanel( endCall, params, UBFPopDelegate )
	if not self.mgr:isEnabledAndResReady() then 
		safeRunCall(endCall)
		return 
	end

	self.mgr:openActivity( false, endCall, false, params, UBFPopDelegate )
end

function MusicMasterPopMudule:onActCheckIconTip(  )
    local popInfo3 = {}
    self:checkPopHasNewMatchTip(popInfo3,{})
    self:popHasNewMatchTip(popInfo3)
end

---------------------------
---------新的过关强弹
---------------------------
function MusicMasterPopMudule:onActEndlevelProgressPrepare( evt )
	
	local data = evt:getData()
	local runtime = data.runtime
    local bCanPop = self:checkCanPopInLevel()
	if bCanPop then 
		runtime:setEnabledProcessNodes(UBFActivityIdConst.kMusicMaster, {
	        [UBFProcessNodeEnum.MUSIC_MASTER] = {
	            -- 流程节点是否可以启动
	            isProcessEnabled = true
	        },
	    })
	end
end

function MusicMasterPopMudule:onPassLevelAddEndCall( )
	local process = UBFProcessManager and UBFProcessManager:getCurrEndProcess()
    local runtime = process and process:getResult("runtime")
    if runtime then
        local bCanPop = self:checkCanPopInLevel()
		if bCanPop then 
			runtime:setEnabledProcessNodes(UBFActivityIdConst.kMusicMaster, {
		        [UBFProcessNodeEnum.MUSIC_MASTER] = {
		            -- 流程节点是否可以启动
		            isProcessEnabled = true
		        },
		    })
		end
    end
end

function MusicMasterPopMudule:onActEndlevelProgressThirdPartStart( evt )

	local data = evt:getData()

	local runtime = data.runtime

    local processNodeKey = data.processNodeKey

    if processNodeKey == UBFProcessNodeEnum.MUSIC_MASTER then
    	local bCanPop = self:checkCanPopInLevel()

    	if bCanPop then

    		local function closeCallback()
    			data:finishProcessCallBack()
    		end

			local function popoutFunc(panel)
		        data:popoutView(panel,UBFProcessNodePopLayerType.POPOUT)
		    end

		    local function removeFunc(panel)
		        data:removeView(panel)
		    end

		    self:doPopInLevel( closeCallback, { popoutFunc = popoutFunc, removeFunc = removeFunc } )
	    else
	    	data:finishProcessCallBack()
	    end
    end
end

function MusicMasterPopMudule:onActEndlevelProgressForceComplete( evt )
	local data = evt:getData()
	local processNodeKey = data.processNodeKey

	if processNodeKey == UBFProcessNodeEnum.MUSIC_MASTER then
		--do nothing
		--没有要处理的数据
	end
end

function MusicMasterPopMudule:checkPopOnStage3(data)
    -- local popInfo3 = {}
    -- local canPopProgress = self:checkPopProgressTip(popInfo3,data)
    -- local canPopTip = self:checkPopHasNewMatchTip(popInfo3,data)
    -- return canPopProgress or canPopTip,popInfo3

    return false
end

----tip的强弹
function MusicMasterPopMudule:checkPopTip(data)
	if not self.mgr:isEnabledAndResReady() then return false end
	if not self:checkCurTimeCanPop() then return false end
	return self:checkPopOnStage3(data)
end

function MusicMasterPopMudule:popOnStage3(popInfo3,endCall)

    safeRunCall(endCall)

    -- local asyncRunner = AsyncRunner:create()
    -- asyncRunner:add(function(done)
    --     self:popProgressTip(popInfo3,done)
    -- end)
    -- asyncRunner:add(function(done)
    --     self:popHasNewMatchTip(popInfo3,done)
    -- end)
    -- asyncRunner:add(function(done)
    --     safeRunCall(endCall)
    --     safeRunCall(done)
    -- end)
    -- asyncRunner:run()
end

function MusicMasterPopMudule:checkPopProgressTip(popInfo,data)
    popInfo.popProgressTip = {}
    if self.mgr:getModel():checkInPre() then---在预选赛阶段
        local nowLevelIsPassed = data.levelPassedInfo
        local levelState = self.mgr:getModel():getLocalValueByKey("play_level_state")
        if not levelState then
            return false
        end
        if nowLevelIsPassed and levelState and levelState.canRecord then
            popInfo.popProgressTip = {
                canPop = true,
                max = self.mgr:getModel():getStreakDoorsillConfig(),
                value = self.mgr:getModel():getPreWinNum(),
            }
            return true
        end
    else
        return false
    end
end

function MusicMasterPopMudule:checkPopHasNewMatchTip(popInfo,data)
    popInfo.popHasNewMatchTip = {}
    local showType, groupPanelShowType = self.mgr:getModel():getPanelShowType()
    local popTimes = self.mgr:getModel():getLocalValueByKey("new_match_pop_times",true) or 0
    if popTimes >= 0 and popTimes < 5 and showType == self.mgr:getConst().MainPanelShowType.kGroup and groupPanelShowType == self.mgr:getConst().GroupPanelShowType.kWaitJoin then
        popTimes = popTimes + 1
        self.mgr:getModel():setLocalValueByKey("new_match_pop_times",true,popTimes)
        popInfo.popHasNewMatchTip = {
            canPop = true,
        }
        return true
    else
        return false
    end
end

---获取连胜的进度
function MusicMasterPopMudule:popProgressTip(popInfo,done)
    local icon = _G.amfBean("IconManager"):getIconByIconKey(IconKey.kMusicMasterIcon)
    if icon and popInfo and popInfo.popProgressTip and popInfo.popProgressTip.canPop then--有icon

        local delegate = {
            value = math.max(popInfo.popProgressTip.value-1,0) ,
            targetValue = popInfo.popProgressTip.value,
            max = popInfo.popProgressTip.max,
            min = 0,
            textMode = 0,
            labelPrefixes = "连胜",
            -- templateId = 1,
            progressChangeTime = 0.3,
        }
        
        delegate.tipsType = HomeIconTipsType.PROGRESS

        local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
        IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP_DIRECTLY, {
            iconKey = IconKey.kMusicMasterIcon,
            iconType = IconTipType.MESSAGE,
            creatorDelegate = delegate,
            typeIndex = 1,
            config = { priority='S' },
        })

        safeRunCall(done)
    else
        safeRunCall(done)
    end
end

---有新的比赛可参加
function MusicMasterPopMudule:popHasNewMatchTip(popInfo)
    local icon = _G.amfBean("IconManager"):getIconByIconKey(IconKey.kMusicMasterIcon)
    if icon and popInfo and popInfo.popHasNewMatchTip and popInfo.popHasNewMatchTip.canPop then
        local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
        IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, {
            iconKey = IconKey.kMusicMasterIcon,
            iconType = IconTipType.MESSAGE,
            creatorDelegate = {
                tipsType = HomeIconTipsType.ONLY_TEXT,
                text = "新的比赛可参加",
            },
            typeIndex = 1,
            popFunc = function()
            end,
        })
    end
end

return MusicMasterPopMudule
