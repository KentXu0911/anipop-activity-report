local NewLevelAtmosphereModule = class("NewLevelAtmosphereModule")
local CloudEventCenter = require"amf.feature.mainscene.module.cloud.event.CloudEventCenter"
    local meta = require"amf.feature.fulllevel.fulllevelatmosphere.config.FullLevelAtmosphereConst"

function NewLevelAtmosphereModule:init(hostMgr,cloudManager)
    self._hostMgr = hostMgr
    self._cloudManager = cloudManager
    self:registerEvent()
    self:tryFirstGetInfoOnFriday()
end

function NewLevelAtmosphereModule:registerEvent()
    CloudEventCenter:register(CloudEventConst.CONTROL_SWITCH, self.onControlSwitch,self)
    CloudEventCenter:register(CloudEventConst.CONTROLLIST_INITIALIZED, self.onControlInit,self)
end

function NewLevelAtmosphereModule:onControlSwitch()

end

function NewLevelAtmosphereModule:onControlInit()
    local ThroneCloudControl = require"amf.feature.fulllevel.fulllevelatmosphere.cloudcontrol.ThroneCloudControl"
    local NewLevelCountdownCloudAnimLayer = require"amf.feature.fulllevel.fulllevelatmosphere.cloudcontrol.NewLevelCountdownCloudControl"
    local RainbowCloudControl = require"amf.feature.fulllevel.fulllevelatmosphere.cloudcontrol.RainbowCloudControl"
    local TopRainbowCloudControl = require"amf.feature.fulllevel.fulllevelatmosphere.cloudcontrol.TopRainbowCloudControl"
    local NpcCloudControl = require"amf.feature.fulllevel.fulllevelatmosphere.cloudcontrol.NpcCloudControl"
    self._cloudManager:registerControl(ThroneCloudControl)
    self._cloudManager:registerControl(NewLevelCountdownCloudAnimLayer)
    self._cloudManager:registerControl(RainbowCloudControl)
    self._cloudManager:registerControl(TopRainbowCloudControl)
    self._cloudManager:registerControl(NpcCloudControl)
end

function NewLevelAtmosphereModule:getWaitPepoleNum() -- 等待冲关人数
    return self:getData():getWaitPepoleNum()
end

function NewLevelAtmosphereModule:getWaitPepoleList()
    return self:getData()
    :getWaitPepoleList()
end


function NewLevelAtmosphereModule:getData()
    return self._hostMgr:getData()
end


function NewLevelAtmosphereModule:requireTopNewLevelCountDownInfo(isFirst)
    --每次登录都要发头像
    local needProfiles = isFirst or not self:getData():hasLocalProfiles()

    local function onSuccess( evt )
        CloudEventCenter:dispatch(CloudEventConst.TOP_NEW_LEVEL_COUNTDOWN_INFO_UPDATE)
    end

    local function onFail(evt)

    end

    local function onCancel()
    end

    self:getData():requestTopNewLevelCountDownInfo({
        uid = _G.amfBean("UserManager"):getUid(),
        needProfiles = needProfiles,
    }, true ):next(function(response)
        safeRunCall(onSuccess, response)
    end, function(response)
        if response:isCancel() then
            safeRunCall(onCancel)
        else
            safeRunCall(onFail, response)
        end
    end)
end

function NewLevelAtmosphereModule:tryFirstGetInfoOnFriday()
	local newLevelOpenTime, curCountDownAreaId = _G.amfBean("LevelUnLockManager"):getNextOpenNewLevelTime()
    local now = TimeKit:timeInSec()
    local topLevel = _G.getTopLevelId()
    local maxLevel =  _G.amfBean("LevelUnLockManager"):getLocalTopLevel() or kMaxLevels
	local openAreaNum = _G.amfBean("LevelUnLockManager"):getLastOpenNewAreaNum()

    if topLevel < maxLevel - (openAreaNum * 15) then return end
    if now >= (newLevelOpenTime - 3600 * 19) and now < newLevelOpenTime  then --预期周五拉
        self:requireTopNewLevelCountDownInfo(true)
    end
    self:setTopNewLevelCountDownInfoClock()
end



local randomCirleMinute = 10
function NewLevelAtmosphereModule:getNextRequireTime()
    local nowTime = TimeKit:timeInSec()
    if not self.clockEndTime then return end
    if not self.lastRandomTime then
        self.lastRandomTime = 60 * randomCirleMinute
    end
    local newRandomTime = math.random(60 * randomCirleMinute)
    local nextRequireTimeNeed = newRandomTime + ( randomCirleMinute * 60) - self.lastRandomTime
    self.lastRandomTime = newRandomTime
    return math.max(nextRequireTimeNeed + TimeKit:timeInSec(),self.clockEndTime - 60 * 60 * 2 - math.random(60 * randomCirleMinute) )--在线的话第一次同步放到16.50~17.00
end

function NewLevelAtmosphereModule:setTopNewLevelCountDownInfoClock()
	local newLevelOpenTime, curCountDownAreaId = _G.amfBean("LevelUnLockManager"):getNextOpenNewLevelTime()
    local PassDayTimer = require"amf.script.tool.timer.PassDayTimer"

    if self.clockEndTime == newLevelOpenTime then
        return
    end
    if self.requireTimeFunc and self.nextRequireTime  then
        PassDayTimer:unregisterEndTimeCallback(self.nextRequireTime , self.requireTimeFunc )
    end


    local topLevel = _G.getTopLevelId()
    local maxLevel =  _G.amfBean("LevelUnLockManager"):getLocalTopLevel() or kMaxLevels
    if topLevel < maxLevel - 30 then return end

    self.clockEndTime = newLevelOpenTime
    self.nextRequireTime = self:getNextRequireTime()

    if self.nextRequireTime > newLevelOpenTime then
        return
    end

    local getNewFunc
    getNewFunc = function()
        self:requireTopNewLevelCountDownInfo()
        local nextRequireTime = self:getNextRequireTime()
        if nextRequireTime < newLevelOpenTime then
            self.nextRequireTime = nextRequireTime
            self.requireTimeFunc = getNewFunc
            PassDayTimer:registerEndTimeCallback(self.nextRequireTime,self.requireTimeFunc)
        end
    end
    self.requireTimeFunc = getNewFunc
    PassDayTimer:registerEndTimeCallback(self.nextRequireTime,self.requireTimeFunc)
end


--打开新关开启面板
function NewLevelAtmosphereModule:showFullLevelOpenPanel( closeCallBack )

    self._hostMgr:tryloadRes(true):next(function()
        local FullLevelOpenPanelVM = require"amf.feature.fulllevel.fulllevelatmosphere.view.FullLevelOpenPanelVM"
        local builder = FullLevelOpenPanelVM.Builder.new()
        local vm = builder:setCloseCallback(closeCallBack)
        :build()
        vm:popout()
    end ,closeCallBack)
end


function NewLevelAtmosphereModule:getAreaIdConfig( areaId )

    local function getTargetConfigByAreaID(wholeConfig, areaID)
        for _, config in ipairs(wholeConfig) do
            if config.areaIDs and table.includes(config.areaIDs, areaID) then
                return config
            end
        end
        return nil
    end

    local mainLevelUnlock = _G.amfBean("LevelUnlockConfigParser"):getUnlockConfigListByConfigType(_G.levelUnlockConst.LevelUnlockConfigType.MAIN_LEVEL)
    local areaConfig = getTargetConfigByAreaID(mainLevelUnlock, areaId)
    if areaConfig then
        local areaIDs = areaConfig.areaIDs
        return areaIDs
    end
    return {areaId}
end


--获取当前的最高关
function NewLevelAtmosphereModule:getCurTopLevel( )
    local curTime = TimeKit:timeInSec()

    --本次
    local curLevelOpenTime, curCountDownAreaId = _G.amfBean("LevelUnLockManager"):getLastOpenNewLevelTime()
    local curAreaIds = self:getAreaIdConfig(curCountDownAreaId)
    local showStartLevel = (curAreaIds[1]-40000-1)*15 + 1
    local showEndLevel = showStartLevel + #curAreaIds*15 - 1

    --如果当前大于开启新关时间，并且是7天内的新关
    if curTime > curLevelOpenTime then
        return true, showStartLevel, showEndLevel
    end
    return false, 0, 0
end


function NewLevelAtmosphereModule:onActEnterStage4(evt)
    self:checkAndPopFullLevelOpenPanel()
end

function NewLevelAtmosphereModule:checkAndPopFullLevelOpenPanel()
    if _G.amfBean("AutoPopupMgr"):checkPointLimitedCheck(PopupCheckPoint.FULL_LEVEL_OPEN_PANEL) then return end
    if not self:checkCanPopFullLevelOpenPanel() then return end

    self:doPopFullLevelOpenPanel()
end


function NewLevelAtmosphereModule:checkCanPopFullLevelOpenPanel( )
    --是否本周新关期间弹过了
    local curWeekEndTime = self._hostMgr:getFullLevelRankModule():getEndTime()

    printx(29,"checkCanPopFullLevelOpenPanel key = ", meta.fullLevelOpenPanelPopKey..'_'..curWeekEndTime)
    local bHadPop = self._hostMgr:getData():getFlagFromLocalByKey( meta.fullLevelOpenPanelPopKey..'_'..curWeekEndTime, false)
    printx(29,"checkCanPopFullLevelOpenPanel 111", bHadPop )
    if bHadPop then return false end

    --判断是否取到了当前的关卡信息
    local bGetSucess, startLevel, endLevel = self:getCurTopLevel()
    printx(29,"checkCanPopFullLevelOpenPanel 222_1", bGetSucess, startLevel, endLevel )
    if not bGetSucess then return false end


    --判断要打的关是否>0
    local userTopPassedLevel = _G.amfBean("LevelAreaManager"):getTopPassedLevel()
    local needPlayLevelNum = endLevel - userTopPassedLevel
    printx(29,"checkCanPopFullLevelOpenPanel 333", needPlayLevelNum )
    if needPlayLevelNum < 0 then return false end

    --判断强弹时间
    local curTime = TimeKit:timeInSec()
    local curDate = os.date2(curTime)
    if not ( (curDate.wday == 6 and curDate.hour >= 19 ) or curDate.wday == 7 or curDate.wday == 1) then
        --只有周五周六周日开启
        return false
    end

    --判断等级情况
    local bGetSucess, curStartLevel, curTopLevel = self:getCurTopLevel()
    local lastTopLevel = curStartLevel - 1

    printx(29,"checkCanPopFullLevelOpenPanel 444", userTopPassedLevel, lastTopLevel )

    if userTopPassedLevel == lastTopLevel then
        --周五7点-7点半不能弹
        local curTime = TimeKit:timeInSec()
        local curDate = os.date2(curTime)

        local bTimeIsOk = false
        if curDate.wday == 6 then
            --对于之前满级的玩家 周五7点-7点半不弹
            if curDate.hour == 19 and curDate.min < 30 then
                printx(29,"checkCanPopFullLevelOpenPanel 555", tts(curDate) )
                return false
            end
        end

    elseif userTopPassedLevel < lastTopLevel then
        --top60-top2弹
        -- local configTopLevel = NewAreaOpenMgr.getInstance():getLocalTopLevel(true)
        local bGetSucess, curStartLevel, curTopLevel = self:getCurTopLevel()
        local lastTopLevel = curStartLevel - 1
        printx(29,'checkCanPopFullLevelOpenPanel 888', curStartLevel, curTopLevel, lastTopLevel )

        if not (lastTopLevel > userTopPassedLevel and lastTopLevel - userTopPassedLevel >= 2 and lastTopLevel - userTopPassedLevel <= 60) then
            printx(29,"checkCanPopFullLevelOpenPanel 999", lastTopLevel, userTopPassedLevel )
            return false
        end
    else
        return false
    end

    printx(29,"checkCanPopFullLevelOpenPanel 101010" )

    return true
end

function NewLevelAtmosphereModule:doPopFullLevelOpenPanel()

    local function onHandleOver()
        printx(12,"doFullLevelCloudPreview onHandleOver")
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.FULL_LEVEL_OPEN_PANEL)
    end

    local function creator()
        self:showFullLevelOpenPanel(onHandleOver)

        --存储弹出记录
        local curWeekEndTime = self._hostMgr:getFullLevelRankModule():getEndTime()
        self._hostMgr:getData():saveFlagToLocalByKey( meta.fullLevelOpenPanelPopKey..'_'..curWeekEndTime, false, true)
    end

    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.FULL_LEVEL_OPEN_PANEL, creator)
end

return NewLevelAtmosphereModule