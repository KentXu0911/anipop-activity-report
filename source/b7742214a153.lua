local HonorRankLog = require "amf.feature.honorrank.HonorRankLog"
local HonorRankIcon = require 'amf.feature.mainscene.module.icon.view.iconbutton.HonorRankIcon'
local HonorRankConst = require "amf.feature.honorrank.config.HonorRankConst"
local HonorRankModel = require "amf.feature.honorrank.model.HonorRankModel"
local HonorRankDC = require "amf.feature.honorrank.dc.HonorRankDC"
local HonorRankConfig = require "amf.feature.honorrank.config.HonorRankConfig"
local HonorRankHttp = require "amf.feature.honorrank.http.HonorRankHttp"
local AsyncRunner = require "amf.script.sugar.AsyncRunner"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local HonorRankEventCenter = require "amf.feature.honorrank.event.HonorRankEventCenter"
local RankConfig = HonorRankConfig.RankConfig

local HonorRankManager = class("HonorRankManager")

function HonorRankManager:ctor()
end

function HonorRankManager:isHonorRankProp(itemId)
    return _G.HonorRankConst.HONOR_RANK_PROP_IDS[tonumber(itemId)] == true
end

function HonorRankManager:setIconManager(mm)
    self._iconManager = mm
end

function HonorRankManager:setAutoPopupMgr(mm)
    self._autoPopupMgr = mm
end

function HonorRankManager:setNetworkStatusManager(mm)
    self._networkStatusManager = mm
end

function HonorRankManager:setPropManager(mm)
    self._propManager = mm
end

function HonorRankManager:setPersonalCenterManager(mm)
   self._personalCenterManager = mm
end

function HonorRankManager:setLevelUnLockManager(mm)
    self._levelUnLockManager = mm
end

function HonorRankManager:setUserManager(mm)
    self._userManager = mm
end

function HonorRankManager:setAssetsUtil(mm)
    self._assetsUtil = mm
end


function HonorRankManager:initialize()
    self.model = HonorRankModel:create()
    HonorRankHttp:setMgr(self)
    self:tryRegisterEvent()
    self:tryRegisterProps()
end

function HonorRankManager:tryRegisterProps()
    require_debug "amf.feature.honorrank.prop.AMFPropHonorRank"
end

function HonorRankManager:tryRegisterEvent()
    HonorRankEventCenter:registerFeature(self)
    IconEventCenter:register(IconEvent.ICON_SYSTEM_READY, self.onIconSystemReady, self)
end

function HonorRankManager:onIconSystemReady(evt)
    self:runEnterMainSceneProcess()
end

function HonorRankManager:onActEnterMainScene(event)
    local data = event:getData()
    if not data.firstEnter and self:canShowHonorRankIcon()  then
        self:runEnterMainSceneProcess()
    end
end

function HonorRankManager:runEnterMainSceneProcess()
    self.asyncRunner = AsyncRunner:create()

    self.asyncRunner:add(function (done)
        if EnvUtil:isMiniGame() then
            self._assetsUtil:loadMiniFiles({"amf/honorrank/texture/peakIconNormal.plist",
                                            "amf/honorrank/texture/honorRankItems.plist",
                                            "amf/personalhub/namemedal/texture/miniMedals/medals.plist",
                                            "amf/personalhub/namemedal/texture/largeMedals/nameMedals.plist"})
                    :next(function()
                self.loadResSucceed = true
                safeRunCall(done)
            end, function()
                self.asyncRunner:clean()
                self.asyncRunner = nil
            end)
        else
            self.loadResSucceed = true
            safeRunCall(done)
        end
    end)

    self.asyncRunner:add(function (done)
        TimerUtil.addAlarm(function()
            safeRunCall(done)
        end, 0.03)
    end)

    if EnvUtil:isMiniGame() then
        self.asyncRunner:add(function (done)
            self:tryCreateHonorIcon(done)
        end)
    else
        self:tryCreateHonorIcon()
    end

    self.asyncRunner:add(function (done)
        if not self:hasLevelReward() then
            if self.asyncRunner then
                self.asyncRunner:clean()
                self.asyncRunner = nil
            end
            return
        end
        self:tryGetPeakRewardData()
        safeRunCall(done)
    end)

    self.asyncRunner:run()
end

--自动领奖流程                          step_1             step_2                 step_3
--获取数据：创建荣誉排行入口按钮==》||--------------|------------>进入强弹队列  ||--------|
--获取数据：点击荣誉排行入口按钮==》||  rewardData  |------>打开荣誉排行界面触发 ||展示奖励|________
--获取数据：满级,满星时刻=======》||---------------|------------->进入强弹队列 ||--------|       |
--                                       ^                                                    |step_4
--                                       |________________clearData___________________________|
--自动进行巅峰奖励领取
function HonorRankManager:tryGetPeakRewardData()
    local asyncRunner = AsyncRunner:create()
    asyncRunner:add(function (done)
        HonorRankHttp:getPeakReward(function()
            safeRunCall(done)
        end, function()
            asyncRunner:clean()
            asyncRunner = nil
        end)
    end)

    asyncRunner:add(function (done)
        self._autoPopupMgr:addPopupConfig(PopupCheckPoint.PEAK_RANK_REWARD, function()
            self:showPeakRewardByData(function()
                AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.PEAK_RANK_REWARD)
            end)
        end)
        safeRunCall(done)
    end)

    asyncRunner:run()
end

--等待展示的巅峰奖励
function HonorRankManager:getWaitingRewardData()
    if self.waitingRewardData and self.waitingRewardData.rewards and #self.waitingRewardData.rewards>0 then
        return self.waitingRewardData
    else
        return nil
    end
end

function HonorRankManager:clearWaitingRewardData()
    self.waitingRewardData = nil
end

function HonorRankManager:setWaitingRewardData(data)
    if not data then return end
    local localData = self.waitingRewardData
    if localData and localData.rewards then --有未处理的信息，merge
        if data.rewards then
            for _,v in ipairs(data.rewards) do
                table.insert(localData.rewards, v)
            end
            if localData.maxRewardLevel and data.maxRewardLevel then
                localData.maxRewardLevel = math.max(localData.maxRewardLevel, data.maxRewardLevel)
            end

            if localData.beginRewardLevel and data.beginRewardLevel then
                localData.beginRewardLevel = math.min(localData.beginRewardLevel, data.beginRewardLevel)
            end

            if localData.maxLevel and data.maxLevel then
                localData.maxLevel = math.max(localData.maxLevel, data.maxLevel)
            end
        end
    else
        self.waitingRewardData = data
    end
end

--打开荣耀殿堂
function HonorRankManager:openHonorRank()
    if not self._networkStatusManager:isNetworkEnabled() then
        CommonTip:showTip("网络连接失败，请联网重试！")
        return
    end
    self:loadRes(function()
        HonorRankHttp:getHonorInfo(function(data)
            if self._mainPanelVM then
                return
            end
            local HonorRankPanelVM = require_debug "amf.feature.honorrank.view.HonorRankPanelVM"
            local vm = HonorRankPanelVM:create({data = data})
            vm:setCloseCallback(function()
                self._mainPanelVM = nil
            end)
            vm:popout()
            self._mainPanelVM = vm
        end)
    end)
end

--根据奖励信息展示奖励
function HonorRankManager:showPeakRewardByData(closeCallback)
    local data = self:getWaitingRewardData()
    self:loadRes(function()
        if data then
            self:showPeakRewardPanel(data, function()
                safeRunCall(closeCallback)
            end)
            self:clearWaitingRewardData()
        else
            safeRunCall(closeCallback)
        end
    end, closeCallback, closeCallback, false)

end

--面板说明，传入排行榜类型rankType
--说明信息面板&历史排行面板，根据type变化内容
function HonorRankManager:showCommonInfoPanel(type,histroyInfo,closeCallback)
    local PanelVM = require_debug "amf.feature.honorrank.view.CommonInfoPanelVM"
    local vm = PanelVM:create({
        type = type,
        histroyInfo = histroyInfo,
    },closeCallback)
    vm:popout()
end

function HonorRankManager:showRankInfoPanel(rankType,closeCallback)
    if rankType == 1 or rankType == 5 or rankType == 6 then
        local PanelVM = require_debug "amf.feature.honorrank.view.CommonInfoPanelVM"
        local vm = PanelVM:create({
            type = rankType
        },closeCallback)
        vm:popout()
    else
        local PanelVM = require_debug "amf.feature.honorrank.view.RankInfoPanelVM"
        local vm = PanelVM:create({
            rankType = rankType,
        }, closeCallback)
        vm:popout()
    end
end

--排行经验说明面板，传入下次新关开启时间
function HonorRankManager:showExpInfoPanel(extraInfo,closeCallback)
    local PanelVM = require_debug "amf.feature.honorrank.view.ExpInfoPanelVM"
    local vm = PanelVM:create(extraInfo, closeCallback)
    vm:popout()
end

--地区选择面板
function HonorRankManager:showLocationPanel(closeCallback, currentLocation)
    local PanelVM = require_debug "amf.feature.honorrank.view.LocationPanelVM"
    local vm = PanelVM:create( closeCallback, currentLocation)
    vm:popout()
end

--空排行提示面板
function HonorRankManager:showEmptyRankPanel(closeCallback)
  local FourthPanelAVM = require "amf.middleware.ui.kit.panel.fourth.FourthPanelAVM"
    local vm
    vm = FourthPanelAVM.Builder.new()
        :setText("大家正在努力闯关中，稍后再来吧！")
        :setButtonsConfig({
            {
                str = {"知道了"},
                touchFunc = function()
                    vm:close()
                end
            }
        })
        :setCloseCallback(closeCallback)
        :setTopUIType(2)
        :build()
    vm:popout()
end

--点赞历史面板
function HonorRankManager:showLikeHistoryPanel(params,closeCallback)
    local PanelVM = require_debug "amf.feature.honorrank.view.LikeHistoryPanelVM"
    local vm = PanelVM:create(params,closeCallback)
    vm:popout()
end

--个人等级面板
function HonorRankManager:showLevelPanel(xxlId,fromRank,closeCallback)
    -- if EnvUtil:isMiniGame() then
    --     safeRunCall(closeCallback)
    --     return
    -- end
    HonorRankHttp:getPeakDetailInfo(xxlId, fromRank, function (data)
        self:loadRes(function()
            local PanelVM = require_debug "amf.feature.honorrank.view.LevelPanelVM"
            local vm = PanelVM:create(data,closeCallback)
            vm:popout()
        end, closeCallback, closeCallback)
    end)
end


--巅峰排行奖励面板
function HonorRankManager:showPeakRewardPanel(data,closeCallback)
    local PanelVM = require_debug "amf.feature.honorrank.view.PeakRewardPanelVM"
    local vm = PanelVM:create(data,closeCallback)
    vm:popout()
end

--巅峰排行PK面板，传入双方数据
function HonorRankManager:showPeakPKPanel(myData, opponentData,closeCallback)
    local PanelVM = require_debug "amf.feature.honorrank.view.PeakRankPKPanelVM"
    local vm = PanelVM:create({
        myData = myData,
        opponentData = opponentData,
    },closeCallback)
    vm:popout()
end

function HonorRankManager:openUserInfo(data, rankType)
    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
        CommonTip:showTip("网络连接失败，请联网重试！")
        return
    end
    if data.uid == 0 then
        CommonTip:showTip("大家正在努力冲榜中，虚位以待")
        return
    end

    local PanelVM = require_debug "amf.feature.honorrank.view.UserInfoPanelVM"
    local function onSuccess(serverData)
        local params = {
            data = data,
            rankType = rankType,
            serverData = serverData
        }
        local vm = PanelVM:create(params)
        vm:popout()
	end
    HonorRankHttp[PanelVM.RankTypeConfig[rankType].HttpQuery](HonorRankHttp, data.uid, onSuccess)
end

 function HonorRankManager:getFullRankInfo(successCallback, failCallback, noLoading)
    if noLoading == nil then noLoading = true end
    HonorRankHttp:queryFullLevelInfo(function (data)
         if not (data and data.nowRecordBean) then
             local _ = failCallback and failCallback(data)
             return
         end
         if HonorRankManager:checkAudit() then
             if not data.nowRecordBean.audit then
                 local _ = failCallback and failCallback()
                 return
             end
         end
        self.fullLevelData = data
        successCallback(data)
    end, failCallback, noLoading)
end

function HonorRankManager:getFullLevelData()
    return self.fullLevelData
end

function HonorRankManager:loadRes(successCallback, errorCallback , cancelCallback, needTip)
    if EnvUtil:isMiniGame() then
        self._assetsUtil:loadMiniFiles({"amf/honorrank/texture/peakIconNormal.plist",
                                        "amf/honorrank/texture/honorRankItems.plist",
                                        "amf/personalhub/namemedal/texture/miniMedals/medals.plist",
                                        "amf/personalhub/namemedal/texture/largeMedals/nameMedals.plist"})
                :next(function()
            self.loadResSucceed = true
            safeRunCall(successCallback)
        end, function()
            if needTip then
                CommonTip:showTip("该功能需要联网,请检查网络状态")
            end
        end, function()
            safeRunCall(errorCallback)
        end)
    else
        self:preloadModuleRes(successCallback, errorCallback, cancelCallback, needTip)
    end
end

function HonorRankManager:preloadModuleRes(successCallback, errorCallback , cancelCallback, needTip)
    if needTip == nil then
        needTip = true
    end
    local function onLoadSuccess()
        self.loadResSucceed = true
        safeRunCall(successCallback)
    end
    local function onLoadError()
        if needTip then
            CommonTip:showTip("该功能需要联网,请检查网络状态")
        end
        safeRunCall(errorCallback)
    end

    AssetsUtil:loadDynamicModule('meta/HonorRank.xml', onLoadSuccess, onLoadError, cancelCallback, needTip)
end

function HonorRankManager:canShowHonorRankIcon(ignoreIcon)
    if ignoreIcon == nil then
        ignoreIcon = false
    end
    if _G.isPlayDemo then return false end
    if not _G.HonorRankConst.OPEN_PEAK_RANK then return false end
    if not _G.amfBean("IconManager"):useUIBottomBarTest() then
        if not self:isLevelEnabled() then
            return false
        end
    end
    if not ignoreIcon then
        if self.honorRankIcon then return false end
    end
    return true
end

function HonorRankManager:isLevelEnabled()
    local topLevel = _G.getTopLevelId()
    return topLevel >= _G.HonorRankConst.HONOR_RANK_OPEN_TOP_LEVEL
end

function HonorRankManager:tryCreateHonorIcon(callback)
    if not self:canShowHonorRankIcon() then
        return
    end
    local button = HonorRankIcon:create()
    self._iconManager:addIcon(button)
    self.honorRankIcon = button
    safeRunCall(callback)
end

--有可领取的巅峰等级奖励
function HonorRankManager:hasLevelReward()
    local optionalDataManager = _G.amfBean("OptionalDataManager")
    local userPeakLevelRewardInfo = optionalDataManager:getTempOptionalDataValue("userPeakLevelRewardInfo")
    return userPeakLevelRewardInfo and userPeakLevelRewardInfo.havaCommonReward
end

function HonorRankManager:checkAudit()
    local optionalDataManager = _G.amfBean("OptionalDataManager")
    if not self._initCheckAudit then
        self._initCheckAudit = true
        local userPeakLevelRewardInfo = optionalDataManager:getTempOptionalDataValue("userPeakLevelRewardInfo")
        local time = userPeakLevelRewardInfo and userPeakLevelRewardInfo.openAuditTime
        self.openAuditTime = time and tonumber(time)
    end
    if not self.openAuditTime then return false end
    local time = TimeKit:time()
    return time > self.openAuditTime
end

--初始化奖励配置
function HonorRankManager:getRewardConfig()
    if self.rewardConfig then return self.rewardConfig end
    local rewardConfig = {}
    local metaRewardConfig = self.model:getPeakLevelRewardConfig()
    if metaRewardConfig and #metaRewardConfig>0 then
        table.insert(rewardConfig, {lv = 0, exp = 0, rewards = {}})
        for idx, item in ipairs(metaRewardConfig) do
            local rewards = self.model:parseReward(item.rewards)
            local lv = tonumber(item.level)
            table.insert(rewardConfig, {
                lv = lv,
                exp = item.exp,
                rewards = rewards
            })
        end
    end
    self.rewardConfig = rewardConfig
    return rewardConfig
end

function HonorRankManager:openRankPanel(rankType)
    if self._honorRankAdapterPanelVM or self._isOpeningHonorRankAdapterPanel then
        return
    end
    local sourceMainPanelVM = self._mainPanelVM
    if not sourceMainPanelVM or sourceMainPanelVM.isDisposed then
        return
    end
    if not self:getDataAdapter(rankType) then
        return
    end
    self._isOpeningHonorRankAdapterPanel = true
    self:requestRankData(rankType, function()
        if sourceMainPanelVM ~= self._mainPanelVM or sourceMainPanelVM.isDisposed then
            self._isOpeningHonorRankAdapterPanel = false
            return
        end
        local HonorRankAdapterPanelVM = require "amf.feature.honorrank.view.HonorRankAdapterPanelVM"
        local rankConfig = HonorRankConfig.RankConfig[rankType]
        local backgrounds = rankConfig and rankConfig.backgrounds
        local loadResList = backgrounds and {backgrounds.main, backgrounds.top} or nil
        local vm = HonorRankAdapterPanelVM:create({rankType = rankType, loadResList = loadResList})
        local didHideMainPanel = false
        vm:setPanelReadyCallback(function()
            self._isOpeningHonorRankAdapterPanel = false
            if sourceMainPanelVM == self._mainPanelVM and not sourceMainPanelVM.isDisposed then
                sourceMainPanelVM:callViewFunc("setVisible", false)
                didHideMainPanel = true
            end
        end)
        vm:setLoadResFailCallback(function()
            self._isOpeningHonorRankAdapterPanel = false
            if self._honorRankAdapterPanelVM == vm then
                self._honorRankAdapterPanelVM = nil
            end
            if didHideMainPanel and sourceMainPanelVM == self._mainPanelVM and not sourceMainPanelVM.isDisposed then
                sourceMainPanelVM:callViewFunc("setVisible", true)
            end
        end)
        vm:setCloseCallback(function()
            self._isOpeningHonorRankAdapterPanel = false
            if self._honorRankAdapterPanelVM == vm then
                self._honorRankAdapterPanelVM = nil
            end
            if didHideMainPanel and sourceMainPanelVM == self._mainPanelVM and not sourceMainPanelVM.isDisposed then
                sourceMainPanelVM:callViewFunc("setVisible", true)
            end
        end)
        self._honorRankAdapterPanelVM = vm
        vm:popout()
    end, function()
        self._isOpeningHonorRankAdapterPanel = false
    end)
end

function HonorRankManager:createMiniPeakFlag(profile, params)
    params = params or {}
    local peakItem, show = self:createPeakFlagByProfile(profile, params.parentNode, params.pos, params.canTouch, params.notFromRank, params.showLv0, 1, -99)
    return peakItem, show
end

function HonorRankManager:createPeakFlagByProfile(profile, parentNode, pos, canTouch, notFromRank, showLv0, scale, from)
    if EnvUtil:isMiniGame() and not self.loadResSucceed then
        return nil
    end
    if not self:canShowHonorRankIcon(true) then
        return nil
    end
    local peakScore = nil
    if profile and profile.peakLevelBean and profile.peakLevelBean.exp and (profile.peakLevelBean.exp > 0 or showLv0) then
        peakScore = profile.peakLevelBean.exp
    elseif profile and profile.peakScore then
        peakScore = profile.peakScore
    end
    local needShowPeakFlag = peakScore and (peakScore > 0 or showLv0)
    if parentNode then
        if parentNode.peakFlag_ui then
            parentNode.peakFlag_ui:updateSelf(profile.xxlId, peakScore, from)
            parentNode.peakFlag_ui:setVisible(needShowPeakFlag)
        elseif needShowPeakFlag then
            parentNode.peakFlag_ui = self:createPeakFlag(profile.xxlId, peakScore, canTouch, notFromRank, from)
            parentNode.peakFlag_ui:setVisible(needShowPeakFlag)
            parentNode.peakFlag_ui:setScale(scale or 1)
            if pos then
                parentNode.peakFlag_ui:setPositionXY(pos.x, pos.y)
            end
            parentNode:addChild(parentNode.peakFlag_ui)
            parentNode.peakFlag_ui:setName("peakFlag_ui")
        end

        return parentNode.peakFlag_ui, needShowPeakFlag
    else
        return self:createPeakFlag(profile.xxlid, peakScore, canTouch, notFromRank, from), true
    end
end

--奖励描述信息
function HonorRankManager:getRewardDes(rewardId, type)
    if rewardId and type then
        local rewardKey = 'honorrank.reward.'..rewardId.."."..type
        local showString = localize(rewardKey)
        if showString ~= rewardKey then
            return showString
        end
    end
    return "神秘的物品"
end

function HonorRankManager:getRewardSprite(reward)
    local tempReward = table.clone(reward)
    tempReward.noDefaultHeadImg = false
    tempReward.noHeadFrame = false
    tempReward.customHeadFrameId = 0
    local ret = _G.GameItemCreator:getPropIcon(tempReward, GameItemCreator.StandardScaleEnum.SCALE_100)
	return ret
end

function HonorRankManager:addRewards(items, sp, fromType, doneCallback)

    if table.isEmpty(items) then
        safeRunCall(doneCallback)
        return
    end

	local itemResPosInWorld = sp and sp:getPositionInWorldSpace() or ccp(360,640)
	local normalItems = {}
    local canPopNameCardPanel = true

    for _,v in pairs(items) do
        local isNormal = false
        if self._propManager:isHeadImage(v.itemId) or
                self._propManager:isNameCardBg(v.itemId) or
                self._propManager:isFlowerSkin(v.itemId) or
                self._propManager:isHeadFrame(v.itemId) then
        else
            table.insert(normalItems, v)
            isNormal = true
        end
        if not isNormal then
            local feature = "full_rank"
            local source = "reward"
            if fromType == 1 then
                feature = "peak_level"
                source = "level_reward"
            end
            HonorRankDC:dcGainSpecialItem(feature, source, v.itemId, v.num)
        end
    end
    if #normalItems>0 then
        local flyContext = FlyItemContext.new(normalItems, itemResPosInWorld)
                                         :setFinishCallback(function ()
        end)
        _G.amfTransaction(TransactionEvent.FLY_ITEMS, flyContext)
    end
    _G.GainPropData:create()
      :setFeature("honorRank")
      :setSource("peakReward")
      --:setPayType(DcPayType.kFree)
      :setProps(items)
      :execute()

    self._personalCenterManager
            :popGetNewDress(items)
            :setEndCallback(function()
                if canPopNameCardPanel then
                    safeRunCall(doneCallback)
                end
            end)
            :popout()
end

--根据经验值创建一个巅峰等级标
function HonorRankManager:createPeakFlag(xxlId, peakExp, canTouch, notFromRank, from)
    local PeakFlagItem = force_require("amf.feature.honorrank.view.PeakFlagItem")
    local peakFlagItem = PeakFlagItem:create(xxlId, peakExp, notFromRank, from)
	peakFlagItem:setTouchEnabled(canTouch)
    return peakFlagItem
end

function HonorRankManager:createPeakFlagByLevel(lv, xxlId, canTouch)
    local PeakFlagItem = require("amf.feature.honorrank.view.PeakFlagItem")
    local peakFlagItem = PeakFlagItem:createByLevel(lv, xxlId)
	peakFlagItem:setTouchEnabled(canTouch)
    return peakFlagItem
end

function HonorRankManager:openRankInfoPanel(rankType)
    local vm = nil
    if rankType == HonorRankConfig.HonorRankType.PEAK_RANK or
            rankType == HonorRankConfig.HonorRankType.FULL_STAR_AREA_RANK or
            rankType == HonorRankConfig.HonorRankType.FULL_LEVEL_AREA_RANK then
        local CommonInfoPanelVM = require "amf.feature.honorrank.view.CommonInfoPanelVM"
        vm = CommonInfoPanelVM:create({
                                     type = rankType,
                                 })
    else
        local RankInfoPanelVM = require "amf.feature.honorrank.view.RankInfoPanelVM"
        vm = RankInfoPanelVM:create({
                                        type = rankType,
                                    })
    end
    vm:popout()
end

--打开巅峰信息详情页
function HonorRankManager:openPeakDetail(xxlId, fromRank, isLevelReward)
    if xxlId == 0 then
        CommonTip:showTip("大家正在努力冲榜中，虚位以待")
        return
    else
        local vm = nil
        HonorRankHttp:getPeakDetailInfo(xxlId, fromRank, function (data)
            self:loadRes(function()
                if not isLevelReward then
                    local LevelPanelVM = require_debug "amf.feature.honorrank.view.LevelPanelVM"
                    vm = LevelPanelVM:create(data)
                else
                    local LevelRewardPanelVM = require_debug "amf.feature.honorrank.view.LevelRewardPanelVM"
                    vm = LevelRewardPanelVM:create(data)
                end
                vm:popout()
            end)
        end)
    end
end

function HonorRankManager:getCommonRankRewardsByActId(actId)
    return self.model:getCommonRankRewardsByActId(actId)
end

function HonorRankManager:getFullStarRecords()
    return self.model:getFullStarRecords()
end

function HonorRankManager:addFullStarRecode(historyInfo)
    self.model:addFullStarRecode(historyInfo)
end

function HonorRankManager:createHonorRankItems(reward, rankType)
    local sp
    local frameName
    if self:isHonorRankProp(reward.itemId) and reward.itemId ~= _G.HonorRankConst.PEAK_RANK_EXP then
        if rankType == 1 then   --满彩
            frameName = 'honorRankItems/colorful_star_'..reward.itemId
        elseif rankType == 2 then   --满星
            frameName = 'honorRankItems/full_star_'..reward.itemId
        else    --满级
            frameName = 'honorRankItems/full_level_'..reward.itemId
        end
        sp = UICreateUtil:createSpriteWithPlist("amf/honorrank/texture/honorRankItems.plist", frameName, true)
    else
        sp = _G.GameItemCreator:getPropIcon(reward)
    end
    return sp
end

function HonorRankManager:checkFullLevelCondition()
    if not _G.HonorRankConst.OPEN_PEAK_RANK then return false end
    local myLevel = _G.getTopLevelId()
    local topLv = self._levelUnLockManager:getLocalTopLevel(true)
    if myLevel < topLv then return false end
    if not __WIN32 then
        local lastShowLv = self.model:getLastFullLevelId()
        if tonumber(lastShowLv) >= topLv then return false end
    end
    return true
end

function HonorRankManager:setLastFullLevel(id)
    self.model:setLastFullLevelId(id)
end

function HonorRankManager:createRankView(rankType, uiData, hostPanel)
    local uiAdapter = self:getUIAdapter(rankType)
    if uiAdapter then
        uiAdapter:setHost(hostPanel)
        uiAdapter:createRankView(uiData)
        return uiAdapter
    end
    return nil
end

function HonorRankManager:getUIAdapter(rankType)
    self._uiAdapters = self._uiAdapters or {}
    if not self._uiAdapters[rankType] then
        self._uiAdapters[rankType] = self:generateUIAdapter(rankType)
    end
    return self._uiAdapters[rankType]
end

--生成UI适配器
function HonorRankManager:generateUIAdapter(rankType)
    if not rankType then return end
    local cfg = RankConfig[rankType]
    if not cfg or not cfg.uiAdapter then return end
    local uiAdapterPath = HonorRankConfig.uiAdapterPath..cfg.uiAdapter
    local uiAdapter
    local dataAdapter = self:getDataAdapter(rankType)
    if dataAdapter then
        pcall(function()
            uiAdapter = require_debug(uiAdapterPath):create(dataAdapter)
        end)
    end
    return uiAdapter
end

function HonorRankManager:removeView(rankType)
    self._uiAdapters = self._uiAdapters or {}
    if rankType and self._uiAdapters[rankType] then
        self._uiAdapters[rankType]:remove()
        self._uiAdapters[rankType] = nil
    end
end

--生成数据适配器
function HonorRankManager:generateDataAdapter(rankType)
    if not rankType then return end
    local rankConfig = RankConfig[rankType]
    if not rankConfig or not rankConfig.dataAdapter then return end
    local dataAdapterPath = HonorRankConfig.dataAdapterPath..rankConfig.dataAdapter
    local dataAdapter
    pcall(function()
        dataAdapter = require_debug(dataAdapterPath):create(rankType)
    end)
    return dataAdapter
end

function HonorRankManager:getDataAdapter(rankType)
    self._dataAdapters = self._dataAdapters or {}
    if not self._dataAdapters[rankType] then
        self._dataAdapters[rankType] = self:generateDataAdapter(rankType)
    end
    return self._dataAdapters[rankType]
end

function HonorRankManager:requestRankData(rankType, successCallback, failCallback)
    local dataAdapter = self:getDataAdapter(rankType)
    if dataAdapter then
        dataAdapter:requestRankData(successCallback, failCallback)
    end
end

function HonorRankManager:cleanAdapter()
    self._uiAdapters = self._uiAdapters or {}
    for k, v in pairs(self._uiAdapters) do
        if isSafeCocosObj(v) then
            v:remove()
        end
    end
    self._uiAdapters = {}
    self._dataAdapters = {}
end

function HonorRankManager:getPeakLv(score)
	score = score or 0
	local config = self:getRewardConfig()
	local lv = 0
	local nextScore = 0
	local lastScore = 0
	for _,v in ipairs(config) do
		if v.exp <= score then
			lv = v.lv
			nextScore = v.exp
			lastScore = v.exp
		else
			nextScore = v.exp
			break
		end
	end

    local lvPercent = (score-lastScore)/(nextScore-lastScore)
	if nextScore == lastScore then
		lvPercent = 1
	end


	lvPercent = math.ceil(lvPercent*100)
	nextScore = nextScore

	return lv, nextScore, lvPercent
end

function HonorRankManager:onActEnterStage4(evt)
    local topLevel = _G.getTopLevelId()
    if topLevel ~= _G.HonorRankConst.HONOR_RANK_OPEN_TOP_LEVEL then return end
    local icon = self._iconManager:getIconByIconKey(IconKey.kHonorRank)
    if icon then
        icon:playUnlock() --刷新下解锁状态
    end
end


return HonorRankManager
