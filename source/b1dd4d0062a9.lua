require "amf.feature.ad.incite.config.InciteConst"
local InciteEventCenter = require "amf.feature.ad.incite.event.InciteEventCenter"
local InciteSdkVersion = require "amf.feature.ad.incite.InciteSdkVersion"
local InciteGameAudioFix = require "amf.feature.ad.incite.model.InciteGameAudioFix"
local InciteDC = require "amf.feature.ad.incite.dc.InciteDC"
local InciteConfig = require "amf.feature.ad.incite.config.InciteConfig"

local function print(...)
    --if ULog then
    --    ULog("InciteManager", ...)
    --else
    --    printx(30, "InciteManager", ...)
    --end
end

local function isValidIDFA(idfa)
    if not idfa then return false end
    if idfa == '' then return false end
    if idfa:gsub('0', ''):gsub('-', '') == '' then
        return false
    end
    return true
end

local function hasValidIDFA()
    local idfa = AppController:getAdvertisingIdentifier() or ""
    return isValidIDFA(idfa)
end

---@class InciteManager
local InciteManager = class("InciteManager")

function InciteManager:ctor()
    self._userManager = nil
    self._levelAreaManager = nil
    self._shimingManager = nil
end

function InciteManager:setUserManager(mgr)
    self._userManager = mgr
end

function InciteManager:setLevelAreaManager(mgr)
    self._levelAreaManager = mgr
end

function InciteManager:setShiMingManager(mgr)
    self._shimingManager = mgr
end

function InciteManager:init()
    local InciteModel = require "amf.feature.ad.incite.model.InciteModel"
    self.model = InciteModel:create()

    self.sceneInfos = {}
    self.extraInfos = {}

    self:initInciteConfig()
    self:initialize()
end

function InciteManager:initInciteConfig()
    local IncitePlatformConfig = require "amf.feature.ad.incite.system.IncitePlatformConfig"
    self.inciteConfig = IncitePlatformConfig:getNativeConfig()
end

function InciteManager:initialize()
    if self.isInit then return end
    _G.amfEC:registerFeature(self)
    if not self:isEnabled() then return end

    if EnvUtil:isWindows() then
        -- local tfn = function() return true end
        --测试开关，包括 VideoAdUnitTest 的后端测试渠道数据等
        -- self.isDebug = tfn
        --广告测试渠道，方便初始化channel，稳定执行到 ready
        -- self.isTestChannel = tfn
        --显示输出
        -- self.isShowPrint = tfn
    end

    self.isInit = true
    self.curPlayInfo = nil
    self.channels = {}
    self.subEntranceType = 1

    local nextDayTime = TimeKit:getDayStartTimeByTS(TimeKit:timeInSec()) + 3600 * 24
    self.nextDayTime = nextDayTime

    self:syncInfo()
    self:loadSplashAd()

    local MainSceneEventCenter = require 'amf.feature.mainscene.core.event.MainSceneEventCenter'
    MainSceneEventCenter:register(MainSceneEvent.View.MAIN_SCENE_UI_LOADED, self.tryShowIcon, self)

    InciteEventCenter:registerTransaction(self)
    InciteEventCenter:registerSystem(self)
    InciteEventCenter:registerGlobal(NormalEvent.PLAY_LEVEL_END, self.onPassLevel, self)
    InciteEventCenter:registerGlobal(NormalEvent.PASS_DAY, function ()
        self.need_sync = true
    end)
    self.need_sync = false
    self:_refresh()

    -- 阻止广告快应用跳转：初始化拦截器
    if EnvUtil:isAndroid() then
        local BlockQuickAppLaunchUtil = require("amf.feature.ad.BlockQuickAppLaunchUtil")
        BlockQuickAppLaunchUtil:getInstance():initialize()
    end

    self:initFAQ()
end

function InciteManager:initFAQ()
    local webJs = {
        playAd = function()
            self:showAds(
                    InciteConst.EntranceType.kFaqV2,
                    function(ads, placementId, state)
                        if EnvUtil:isAndroid() then
                            if state == InciteConst.AdsFinishState.kCompleted then
                                local AnimalWebJsBridge = luajava.bindClass("com.happyelements.android.AnimalWebJsBridge");
                                AnimalWebJsBridge:notifyPlayFinished(true)
                            else
                                local AnimalWebJsBridge = luajava.bindClass("com.happyelements.android.AnimalWebJsBridge");
                                AnimalWebJsBridge:notifyPlayFinished(false)
                            end
                        elseif EnvUtil:isIOS() then
                            if state == InciteConst.AdsFinishState.kCompleted then
                                FAQManager:getInstance():notifyPlayFinished(true)
                            else
                                FAQManager:getInstance():notifyPlayFinished(false)
                            end
                        end
                    end,
                    function()
                        if EnvUtil:isAndroid() then
                            local AnimalWebJsBridge = luajava.bindClass("com.happyelements.android.AnimalWebJsBridge");
                            AnimalWebJsBridge:notifyPlayError()
                        elseif EnvUtil:isIOS() then
                            FAQManager:getInstance():notifyPlayError()
                        end
                    end
            )
        end,
        isAdReady = function()
            if not self:isEntryEnable(InciteConst.EntranceType.kFaqV2) then
                return false
            end
            local sdkName = self:getReadySdk(nil, InciteConst.EntranceType.kFaqV2);
            return sdkName == 'sigmobIOSNew' or sdkName == 'sigmobAndroidNew'
        end,
    }
    if EnvUtil:isAndroid() then
        local AnimalWebJsBridge = luajava.bindClass("com.happyelements.android.AnimalWebJsBridge");
        local viewDelegate = luajava.createProxy('com.happyelements.android.AnimalWebJsBridge$LuaAdImpl', {
            playAd = webJs.playAd,
            isAdReady = webJs.isAdReady,
        })
        AnimalWebJsBridge:setLuaAdImpl(viewDelegate)
    elseif EnvUtil:isIOS() then
        local FAQManagerBridge_LuaImpl = waxClass({"FAQManagerBridge_LuaImpl"})
        function FAQManagerBridge_LuaImpl:playAd(...)
            return webJs.playAd(...)
        end
        function FAQManagerBridge_LuaImpl:isAdReady(...)
            return webJs.isAdReady(...)
        end

        FAQManager:getInstance():setLuaImpl(FAQManagerBridge_LuaImpl:init())
    end
end

function InciteManager:syncInfo(response)
    local data = response and response:getData() or nil
    self.sceneInfos = {}
    self.addTwoStepComboInfoData = nil

    self.info = data and data.videoSDKInfo or self.info

    if EnvUtil:isAndroid() and _G.packageMode == "sigmobtest" then
        local info2 = require "amf.feature.ad.incite.config.SigmobTestInfo"
        info2 = table.deserialize(info2)
        if not self.info then
            self.info = info2
        else
            table.insert(self.info.config, info2.config[1])
            table.insert(self.info.enableSDKs, info2.enableSDKs[1])
        end
    end

    if EnvUtil:isWinMacSimulator() then
        if self.info then
            for _, v in pairs(self.info.enableSDKs or {}) do
                v.first = 'Win32Ad'
            end

            for _, v in pairs(self.info.config or {}) do
                v.first = 'Win32Ad'
            end
        end
    end

    if self.info and self.info.enableSceneUIMap then
        local r = {}
        for k, v in pairs(self.info.enableSceneUIMap) do
            r[tonumber(k)] = tonumber(v)
        end
        self.info.enableSceneUIMap = r
    end

    if EnvUtil:isDevelopMode() then
        --self:print("enableSceneUIMap:", table.tostring(self.info and self.info.enableSceneUIMap))
    end

    -- print("syncInfo", tts_d(self.info), self:isEnabled())
    if self.info and self:isEnabled() then
        print("initSdk", self:checkState(), self:checkCondition())

        ---激励视频实时加载
        local preLoadClose = 0
        if self.info.preLoadClose == true then
            preLoadClose = 1
        end
        DcUtil:sendPreLoadClose(preLoadClose, self:getDcParam_AdLeftTimes())

        if self:checkState() or self:checkCondition() then
            self:initSdk()
        else
            self:removeHomeBtn()
        end
    else
        self:removeHomeBtn()
    end

    if self:needFindNextPrePropId() then
        self:findNextPrePropId()
    end

    if self.info and self.info.ai_config then
        local last_dc_day = self.model:getValue("last_dc_day")
        local now = time2day()
        if last_dc_day < now then
            self.model:setValue("last_dc_day", now)
            InciteDC:adsInciteAI()
        end
    end

    self:parseDelayCloseStrategy()
    self:dcEnabledEntry()
end

function InciteManager:_refresh()
    self.need_sync = false

    local plusUpVersion
    if AddTwoStepVideoComboUtil and AddTwoStepVideoComboUtil.getCurrClientVersion then
        plusUpVersion = AddTwoStepVideoComboUtil:getCurrClientVersion()
    end
    local params = {
        deviceUdid = MetaInfo:getInstance():getUdid(),
        videoSdkClientVersion = self:getSdkVersion(),
        plusUpVersion = plusUpVersion,
        supportAdVersions = self:getSupportADVersion(),
        -- rtuf ai干预使用
    }
    self.model:requestMainInfo(params):next(function(response)
        self:syncInfo(response)
        DcUtil:adDelayClose(self:getEnableFlag(), self:getDelayCloseFlag())
    end, function(response)
    end)
end

function InciteManager:checkState()
    --剩余次数
    local hasRemaind = (self.model:getValue("remaindTime") or 0) > 0
    return hasRemaind
end

function InciteManager:saveState()
    self.model:setValue("remaindTime", self:getRemaindTime())
end

--初始化条件
function InciteManager:checkCondition()
    if not self.info then return false end

    local hasRemaind = false
    for t = 2, 4 do
        local count = self:getCount(t)
        if count > 0 then
            hasRemaind = true
            break
        end
    end

    local enableScenes = self.info.enableScenes or {}

    local enable = false
    for _, scene in ipairs(enableScenes) do
        for k, v in pairs(InciteConst.EntranceType) do
            if scene == v then
                enable = true
                break
            end
        end
    end

    return hasRemaind and enable
end

function InciteManager:initSdk()
    if not self.info then return end
    self:createChannel()
    local enableSDKs = self:getEnableSDKs()
    local needRemoveIcon = true
    for _,sdk in ipairs(enableSDKs) do
        local ads_name = sdk.first
        local state = 0
        local channel = self.channels[ads_name]
        if channel and channel:isSupported() then
            state = 1
            needRemoveIcon = false
            if not channel.isInit then
                local PersonalIncite = require "amf.feature.ad.incite.system.PersonalIncite"
                channel:initSdk(
                    PersonalIncite:isEnabled(),
                    self._shimingManager:isAdult() or false
                )
            end
        end
        
    end

    if needRemoveIcon then
        if not EnvUtil:isWinMacSimulator() then
            self:removeHomeBtn()
        end
    elseif not self.hasTryShowIcon then
        setTimeOut(function ()
            self:tryShowIcon()
            self.hasTryShowIcon = true
        end, self:getIconShowTime())
    end
end

local cached_enabled_sdk_name = 'unknown'
local debug_config = {
    appId = "1282",
    appKey = "27531c7c64157934",
    placementIds = {
        "e01480dcea2","e01480dcea2","e01480dcea2","e01480dcea2",
    },
}

function InciteManager:getAppSdkConfigInfo(name)
    if not self.info then return nil end
    local config = self.info.config
    for _, info in ipairs(config or {}) do
        if info.first == name or EnvUtil:isWinMacSimulator() then
            return table.deserialize(info.second)
        end
    end
    return nil
end

function InciteManager:createChannel()
    if not self.inciteConfig then return end
    if not self.info then return end

    --local config = self.info.config

    --[[
    local function getAppInfo(name)
        for _, info in ipairs(config) do
            if info.first == name or EnvUtil:isWindows() then
                return table.deserialize(info.second)
            end
        end
        return nil
    end
    --]]
    local testPara = self:isTestChannel()

    for name, conf in pairs(self.inciteConfig) do
        --local appinfo = getAppInfo(name)
        local appinfo = self:getAppSdkConfigInfo(name)
        if conf.delegate and appinfo and not self.channels[name] then
            if EnvUtil:isAndroid() then
                if PlatformConfig:isPlatform(PlatformNameEnum.kOppo) then
                    if name == "Oppo" then
                        -- 走Oppo自己的广告渠道时，允许启动时初始化广告SDK
                        pcall(function()
                            local MainActivityHolder = luajava.bindClass('com.happyelements.android.MainActivityHolder')
                            local preferences = MainActivityHolder.ACTIVITY:getSharedPreferences("animal_common_info", 0)
                            local editor = preferences:edit()
                            editor:putBoolean("oad_lazy_init", false)
                            editor:commit()
                        end)
                    elseif name == "sigmobAndroidNew" then
                        -- 走Sigmob的广告渠道时，禁止启动时初始化广告SDK
                        pcall(function()
                            local MainActivityHolder = luajava.bindClass('com.happyelements.android.MainActivityHolder')
                            local preferences = MainActivityHolder.ACTIVITY:getSharedPreferences("animal_common_info", 0)
                            local editor = preferences:edit()
                            editor:putBoolean("oad_lazy_init", true)
                            editor:commit()
                        end)
                    end
                end
                pcall(function ()
                    if testPara then
                        appinfo = debug_config
                    end
                    if _G.LuaJavaConvert and _G.LuaJavaConvert.hasJavaMethod(conf.delegate, "setAppInfo") then
                        conf.delegate:setAppInfo(appinfo.appId, appinfo.appKey)
                    end

                end)
            end

            if EnvUtil:isOhos() then
                if conf.delegate.setAppInfo then
                    conf.delegate:setAppInfo(appinfo.appId, appinfo.appKey)
                end
            end



            local aiPlacementIds = {}
            for et, pid in pairs(appinfo.aiPlacementIds or {}) do
                aiPlacementIds[tonumber(et)] = pid
            end

            local placementIds = {}
            for et, pid in pairs(appinfo.placementIds) do
                placementIds[tonumber(et)] = pid

                if not aiPlacementIds[tonumber(et)] then
                    aiPlacementIds[tonumber(et)] = pid
                end
            end

            local actPlacementIds = placementIds
            if self:isAiGroup() then
                actPlacementIds = aiPlacementIds
            end

            local interstitialIds
            if appinfo.interstitialIds then
                interstitialIds = {}
                for et, pid in pairs(appinfo.interstitialIds) do
                    interstitialIds[tonumber(et)] = pid
                end
            end

            if EnvUtil:isIOS() and InciteSdkVersion:getIOSLatestModify() >= 2 then
                -- 新版本广告位id使用新字段里的配置
                local placementId
                local interId

                if hasValidIDFA() then
                    placementId = appinfo.placementWithIdfa
                    interId = appinfo.interstitialWithIdfa
                else
                    placementId = appinfo.placementWithoutIdfa
                    interId = appinfo.interstitialWithoutIdfa
                end

                for k, v in pairs(actPlacementIds) do
                    if not self:isSoloEntranceType(k) then
                        actPlacementIds[k] = placementId
                    end
                end

                if interstitialIds then
                    for key, value in pairs(interstitialIds) do
                        interstitialIds[key] = interId
                    end
                end
            end

            local AdNode = require "amf.feature.ad.incite.model.AdNode"
            local channel = AdNode.new(name, conf.flag, conf.delegate, actPlacementIds, interstitialIds,self)
            self.channels[name] = channel

            cached_enabled_sdk_name = name

            if EnvUtil:isAndroid() and name == 'sigmobAndroidNew' and InciteManager:getSdkVersion() >= 1 then
                local ImageAdMgr = require "amf.feature.ad.incite.ImageAdMgr"
                ImageAdMgr:init(appinfo.appId, appinfo.appKey, appinfo.nativeAdPlacementId)
            end
        end
    end
end

--sdk初始化到主动尝试显示icon的时间
function InciteManager:getIconShowTime()
    if self.info and self.info.showTime then
        return self.info.showTime
    end

    return 60
end

function InciteManager:getSdkPriority(name)
    local enableSDKs = self:getEnableSDKs()

    for priority, sdk in ipairs(enableSDKs) do
        if sdk.first == name then
            return priority
        end
    end
    return nil
end

function InciteManager:getInfo()
    return self.info
end


-- 关卡前置道具的id,根据后端的种子和权重随机
-- 开始关卡场景版本的4，5版本才会需要
function InciteManager:needFindNextPrePropId()
    if self.info then
        local version = self:getSceneUIVersion(InciteConst.EntranceType.kStartLevel)
        if version == 5 then
            return true
        end
    end

    return false
end

function InciteManager:findNextPrePropId()
    local isEffective = false  -- vip不需要这个规则， 只更改图标就行了
    for i = 1, 16 do
        self:_findNextPrePropId()
        if not (isEffective and self.info and self.info.prePropId == UPropId.INITIAL_2_SPECIAL_EFFECT) then
            break
        end
    end
end

function InciteManager:_findNextPrePropId()
    if self.info and self.info.prePropsV2 and self.info.prePropRandSeed then
        local preItemsId, preItemsWeight = self:getRandomPrePropData()
        local randomSeed = self.info.prePropRandSeed
        local prePropsV2Weight = preItemsWeight
        local prePropId = 0

        -- printx(30, "InciteManager:random info", tts(preItemsId), tts(preItemsWeight), randomSeed)
        if randomSeed and prePropsV2Weight and preItemsId then
            local array = {}
            local lastWeight = 0
            for i = 1, #prePropsV2Weight do
                array[i] = lastWeight + prePropsV2Weight[i]
                lastWeight = array[i]
            end

            local uid = tonumber(self._userManager:getUid())
            math.randomseed(randomSeed + uid)
            local randomNum = math.random(lastWeight)

            local str = ""
            local beforeWeight = 0
            for i = 1, #array do
                str = str .. string.format(
                    "道具:%s, 命中范围:%d~%d\n",
                    tostring(preItemsId[i]), beforeWeight + 1, array[i]
                )
                beforeWeight = array[i]
            end
            for i = 1, #array do
                if randomNum <= array[i] then
                    prePropId = preItemsId[i]
                    break
                end
            end
            self.info.prePropId = prePropId
            self.info.prePropRandSeed = randomSeed + 1
            --printx(30, "InciteManager:\n", str, "\n随机种子:" .. tostring(randomSeed + uid),
            --    "随机范围:1~" .. tostring(lastWeight), "随机结果:" .. tostring(randomNum),
            --    "随机道具:" .. tostring(self.info.prePropId))
        end
    end
end

-------------itemId,数量,权重--数量暂时不需要
--后端数据格式为" 10087:1:20,10099:1:20"
--确保后端数据格式不会修改否则解析就出错了
function InciteManager:getRandomPrePropData()
    if self.info and self.info.prePropsV2 and self.info.prePropsV2 ~= "" then
        local preItemsId = {}
        local preItemsWeight = {}

        local weightStr = self.info.prePropsV2
        local weightStr1 = string.split(weightStr, ",")

        for _, str in pairs(weightStr1) do
            local weightStr2 = string.split(str, ":")
            if weightStr2[1] and weightStr2[3] then
                table.insert(preItemsId, tonumber(weightStr2[1]))
                table.insert(preItemsWeight, tonumber(weightStr2[3]))
            else
                return
            end
        end

        return preItemsId, preItemsWeight
    end
end

--延迟关闭策略
--需求文档：https://rzvo5fieru.feishu.cn/wiki/WJytwByruiML0ikRkEUcE3Iwn9g#A5iMd3b9zo83SlxNiCZcIwCDn3g
function InciteManager:parseDelayCloseStrategy()
    self.delayCloseInfo = nil
    if self.info  then
        local delayConfig = self.info.newDelayCloseClientBean
        if delayConfig then
            local randomList = {}
            for _, v in ipairs(delayConfig.metaList or {}) do
                local hourRangePair = string.split(v.hoursRange, "~")  -- 0~140
                local cdRangePair = string.split(v.cdMinutesRange, "~") -- 60~120
                table.insert(randomList, {
                    minHour = tonumber(hourRangePair[1]) or 0,
                    maxHour = tonumber(hourRangePair[2]) or 0,
                    minCd = tonumber(cdRangePair[1]) or 0,
                    maxCd = tonumber(cdRangePair[2]) or 0,
                })
            end

            local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
            self.delayCloseInfo = {
                bufferEndTime = TimeUtil:convertSec(delayConfig.bufferEndTimestamp), --缓冲期结束时间戳
                randomList = randomList,
            }
        end
    end
end

--延迟关闭策略生效时，播放视频之后增加一定的随机cd，cd之后才能再次观看
--这个cd是针对整个激励视频的，不区分场景，cd是纯前端的限制，清数据之后会丢失
function InciteManager:setDelayCloseData()
    if not self.delayCloseInfo then return end

    local diffTime = TimeKit:timeInSec() - self.delayCloseInfo.bufferEndTime
    if diffTime <= 0 then return end

    local diffHour = math.floor(diffTime / 3600)
    for _, v in ipairs(self.delayCloseInfo.randomList) do
        if diffHour >= v.minHour and diffHour < v.maxHour then
            local cd = math.random(v.minCd + 1, v.maxCd) --左开右闭区间
            self.model:setValue("delayCdEndTime", TimeKit:timeInSec() + (cd * 60))
            break
        end
    end
end

--延迟关闭策略，cd没到不让看视频
function InciteManager:isInDelayCloseCd()
    local delayCdEndTime = self.model:getValue("delayCdEndTime")
    if delayCdEndTime then
        if TimeKit:timeInSec() < delayCdEndTime then
            return true
        end
    end
end

-- 进入了缓慢关闭策略（关闭中，关闭后都算）
function InciteManager:isInDelayCloseStrategy()
    -- 只要后端返回了 newDelayCloseClientBean，就意味着处于关闭策略中
	if self.delayCloseInfo then 
		return true
	end
	return false
end

function InciteManager:isSigmobAd(name)
    if EnvUtil:isIOS() then
        return name == "sigmobIOSNew"
    elseif EnvUtil:isAndroid() then
        return name == "sigmobAndroidNew"
    end
    return false
end

-- 可观看用户点
function InciteManager:dcEnabledEntry()
    if self.info and self:isEnabled() then

        self.dcEnabledEntry = _G.doNothing

        local enableList = {}

        for k, v in pairs(InciteConst.EntranceType) do
            if v < InciteConst.VirtualEntranceBoundary then
                local enable = self:isEntryEnable(v)
                table.insert(enableList, {entry = v, enable = enable and 1 or 0})
            end
        end

        table.sort(enableList, function(a, b) return a.entry < b.entry end)

        local dc = {}
        for k, vv in ipairs(enableList) do
            table.insert(dc, tostring(vv.enable))
        end

        dc = table.concat(dc, '_')

        DcUtil:UserTrack({category = 'user_filtering', sub_category = 'incentive_video', t1 = dc})
    end
end

function InciteManager:getRewardPool()
    if self.info and self.info.rewardPoolToday then
        return self.info.rewardPoolToday
    end
    return {}
end

function InciteManager:isTestChannel()
    return false--MaintenanceManager:getInstance():isEnabled("VideoAdTestPara", false)
end

function InciteManager:isDebug()
    return false
end

function InciteManager:isShowPrint()
    return EnvUtil:isDevelopMode() and MaintenanceManager:getInstance():isEnabled("InciteDebug", false)
end

function InciteManager:print(...)
    if self:isShowPrint() then
    end
end

function InciteManager:generatePlayVideoId()
    return 'play_video_id_' .. TimeKit:time() .. '_' .. math.random(1, 1024*1024*1024)
end

function InciteManager:_playReadyVideo(readySdkId, entranceType, immediately)
    local function doPlay()
        local playedPlacementId = self.channels[readySdkId]:play(self.entranceType)

        if self.curPlayInfo then
            self.curPlayInfo.playedPlacementId = playedPlacementId
        end

        self.playVideoId = self:generatePlayVideoId()



    end
     if immediately then
         doPlay()
     else
         _G.amfBean("NetworkCheckLogic")
         :execute(true)
         :next(function()
             doPlay()
         end,function()
             CommonTip:showTip(localize("dis.connect.warning.tips"))
             self:onAdsError(readySdkId, InciteConst.AdsError.kNetError, "no network", entranceType)
         end)
     end
end

-- 视频没加载好时，等待n秒，n秒内加载好了就自动播放，没好才走失败回调
-- waitDuration: 秒
function InciteManager:_waitUntilVideoIsReady(waitDuration, entranceType)
    local vm
    local passedDuration = 0

    local function stopWaitingTimer()
        if self.waitForSDKReadyTimer then
            TimerUtil.removeAlarm(self.waitForSDKReadyTimer)
            self.waitForSDKReadyTimer = nil
        end
    end

    local function removeLoadingAnimation()
        if vm then
            vm:close()
        end
    end

    local function onGiveUpWaiting(canceledByPlayer)
        stopWaitingTimer()
        removeLoadingAnimation()

        if canceledByPlayer then
            CommonTip:showTip("视频加载已取消", "negative")
        else
            CommonTip:showTip("视频加载失败，请检查网络设置或稍后重试~", "negative")
        end

        self:onAdsError(nil, InciteConst.AdsError.kVideoNotReady, "no ad", entranceType, nil, true)

        self:tryLoadAdIfNotReady("no_ad")
    end

    local function checkSDKReadyStatus()
        local readySdkId = self:getLoadSucSdk(true, self.entranceType)
        if readySdkId then
            stopWaitingTimer()
            removeLoadingAnimation()

            if self.curPlayInfo then
                self.curPlayInfo["sdk"] = readySdkId
            end
            self.readyAd = readySdkId

            self:_playReadyVideo(readySdkId, entranceType, true)
        else
            if passedDuration >= waitDuration then
                onGiveUpWaiting()
            end
        end
    end

    -- 每秒检测一次sdk状态
    local function onTimerTick()
        passedDuration = passedDuration + 1
        checkSDKReadyStatus()
    end
    stopWaitingTimer()
    self.waitForSDKReadyTimer = TimerUtil.addAlarm(onTimerTick, 1, waitDuration)

    -- 增加一个等待中的动画
    local function closeCall(click)
        if click then
            onGiveUpWaiting(true)
        end
    end

    local LoadingPanelVM = require "amf.middleware.ui.kit.panel.loading.LoadingPanelVM"
    vm = LoadingPanelVM.Builder.new()
        :setLoadingText("视频加载中")
        :setShowBtnClose(true)
        :setCloseCallback(closeCall)
        :build()
end

function InciteManager:tryLoadAdIfNotReady(reason)
    if not self.isInit then return end
    for name, channel in pairs(self.channels or {}) do
        if channel.isInit then
            channel:tryLoadAdIfNotReady(reason)
        end
    end
end

function InciteManager:tryLoadAd(reason)
    if not self.isInit then return end
    for name, channel in pairs(self.channels or {}) do
        if channel.isInit then
            channel:tryLoadAd(reason)
        end
    end
end

function InciteManager:isNeedReloadiOSAds()
    local curScene = Director:sharedDirector():getRunningScene()
    if not curScene then return false end

    if curScene.name == "GamePlaySceneUI" then
        return false
    elseif UBFGamePlayScene and curScene:is(UBFGamePlayScene) then
        return false
    end
    return true
end

function InciteManager:hasVideoChance()
    local has = false
    for k, v in pairs(InciteConst.EntranceType) do
        if v < InciteConst.VirtualEntranceBoundary then
            local enable = self:isEntryEnable(v)
            local count = self:getCount(v)
            if enable and count > 0 then
                has = true
                break
            end
        end
    end
    return has
end

function InciteManager:isVirtualEntranceType(et)
    return et and et >= InciteConst.EntranceType.kVirtual_1 and et <= InciteConst.EntranceType.kVirtual_3
end

function InciteManager:isSoloEntranceType(et)
    return table.includes(InciteConst.SoloEntranceType, et)
end

-- 配置编辑平台： video_sdk_global_v2中还有开启等级限制，目前是500级。
function InciteManager:isEnabled()
    --
--
--
--
--
--
--


    if self._shimingManager:isforbiddenForJuvenile() then
        return false
    end


    if EnvUtil:isOhos() then ---鸿蒙直接返回ture
        return true
    end

    if EnvUtil:isIOS() then
        -- 1.157版本sdk问题，iOS端如果是Mac版就屏蔽激励视频，后续如果sdk修复了再删除这个逻辑
        if AppController:isiOSAppOnMac() then
            return false
        end
        
        if AppController:getSystemVersion() <= 9 then
            return false
        end

        local enable = MaintenanceManager:getInstance():isEnabled("IosVideoAdsFeature", false)
        if not enable then return false end

        local iosVideoAdsLowDevice = MaintenanceManager:getInstance():isEnabled("IosVideoAdsLowDevice", false)
        if not iosVideoAdsLowDevice and _G.__isLowDevice then return false end

        return true
    end

    if EnvUtil:isAndroid() then
        local switchKey = "AndroidVideoAdsLowDevice"
        local androidVideoAdsLowDevice = MaintenanceManager:getInstance():isEnabled(switchKey, false)
        if not androidVideoAdsLowDevice and _G.__androidMemoryTag then
            local tag = tonumber(MaintenanceManager:getInstance():getExtra(switchKey))
            if tag and _G.__androidMemoryTag == tag then
                return false
            end
        end

        if PlatformConfig:isPlatform(PlatformNameEnum.kMI) then
            if getOSVersionNumber() < 4.4 then
                return false
            end
        end

        if PlatformConfig:isPlatform(PlatformNameEnum.kOppo) then
            local gameMajorVer = 0
            if getGameVersionNum then
                gameMajorVer = getGameVersionNum()
            end
            gameMajorVer = tonumber(gameMajorVer) or 0

            if gameMajorVer <= 115 then
                return false
            end
        end

        return true
    end

    if EnvUtil:isMiniGame() then
        -- 支付宝pc端屏蔽激励视频
        if EnvUtil:isALIPAYMiniGame() and EnvUtil:isMiniGameBrowser() then
            return false
        end
        -- 抖音直播伴侣(windows平台)屏蔽激励视频
        if EnvUtil:isDYMiniGame() and EnvUtil:isMiniGameWindows() then
            return false
        end
        return true
    end
end

function InciteManager:getSdkVersion()
    return InciteSdkVersion:getSdkVersion()
end

function InciteManager:getEnableSDKs()
    if self.info then
        local enableSDKs = self.info.enableSDKs or {}
        local function less( p,n )
            return tonumber(p.second) < tonumber(n.second)
        end
        table.sort(enableSDKs, less)
        return enableSDKs
    end

    return {}
end

function InciteManager:getWhiteListSdk(isClick, entranceType)
    local enableSDKs = self:getEnableSDKs()
    local max = #enableSDKs

    if max <= 0 then return nil end

    if self.curWhiteSdkIndex == nil then
        self.curWhiteSdkIndex = LocalDB:getInt("incite.video.white.list.index", 0)
    end

    local curIndex = self.curWhiteSdkIndex
    if isClick then
        curIndex = curIndex + 1
    end

    if curIndex > max or curIndex == 0 then curIndex = 1 end
    self.curWhiteSdkIndex = curIndex

    for index = curIndex, max do
        local ads_info = enableSDKs[index]
        if ads_info and self.channels[ads_info.first] then
            local ads_name = ads_info.first
            local isReady = self.channels[ads_name]:isReady(entranceType)
            if isReady then
                LocalDB:setInt("incite.video.white.list.index", index)
                return ads_name
            else
                self:sendInvokeVideoSDKErrorToServer(ads_name)
            end
        end
    end

    return nil
end

-- logData:一个查线上问题的临时log，之后可删
function InciteManager:getReadySdk(isClick, entranceType)
    if self:canPreLoadAds() then ---预加载
        return self:getLoadSucSdk(isClick, entranceType)
    end

    ---激励视频实时加载
    local enableSDKs = self:getEnableSDKs()
    if #enableSDKs == 0 then
        self:print("配置没有任何SDK开启！")
        return nil
    end

    for _,sdk in ipairs(enableSDKs) do
        local ads_name = sdk.first
        local isReady = false
        if self.channels[ads_name] then
            isReady = true
        end

        if isReady then
            return ads_name
        end
    end

end

---预加载成功的sdk
function InciteManager:getLoadSucSdk(isClick, entranceType)
    if not self.info then return nil end

    entranceType = entranceType or self.entranceType

    local enableSDKs = self.info.enableSDKs or {}
    local function less(p, n)
        return tonumber(p.second) < tonumber(n.second)
    end
    table.sort(enableSDKs, less)


    if self.info.inWhitelist then
        return self:getWhiteListSdk(isClick, entranceType)
    end

    for _, sdk in ipairs(enableSDKs) do
        local ads_name = sdk.first
        local isReady = false
        if self.channels[ads_name] then
            pcall(function ()
                isReady = self.channels[ads_name]:isReady(entranceType)
            end)
        end


        if isReady then
            return ads_name
        else
            if isClick then
                self:sendInvokeVideoSDKErrorToServer(ads_name)
            end
        end
    end

    if #enableSDKs == 0 then
        self:print("配置没有任何SDK开启！")
    end

    return nil
end

function InciteManager:getCurPlayingAdInfo()
    if self.curPlayingAdInfo then
        return self.curPlayingAdInfo
    else
        return {placementId = "", adType = InciteConst.AdType.kInvalid}
    end
end

function InciteManager:onAdsReady(name, placementId)
    self:print("onAdsReady :", name, placementId)
    self:refreshIcons (name)
end

function InciteManager:refreshIcons (name)
    if self.panel then
        self.panel:refresh()
    end

    if not self.info then return end

    local showIcon = false

    local enableSDKs = self:getEnableSDKs()

    if #enableSDKs > 0 then
        if name == enableSDKs[1].first then
            showIcon = true
        end
    end

    if self.hasTryShowIcon or showIcon then
        setTimeOut(function ()
            self:tryShowIcon()
        end, 0)
    end
end

function InciteManager:onAdsPlayed(name, placementId, adInfo, adType)
    InciteGameAudioFix.ad_showing = true

    -- 缓存当前播放视频广告信息（打点可能要用）
    self.curPlayingAdInfo = {
        placementId = placementId,
        adType = adType,
    }

    self:print("onAdsPlayed :", name, placementId, adInfo, adType)


    self:getTracer(self.entranceType, self.subEntranceType):notify(InciteEvent.sdk_callback_play_started, {
        entry = self.entranceType,
        sdkName = name,
        subEntry = self.subEntranceType,
        placementId = placementId,
        playId = UBFGamePlayBridgeInvoker and UBFGamePlayBridgeInvoker:getPlayId(),
        source = self.showPanelSource,
        adInfo = adInfo,
        adv_type = adType,
    })

    local info = self.curPlayInfo
    if info and info.listener then
        if type(info.listener.onPlayDidStart) == 'function' then
            info.listener.onPlayDidStart()
        end
    end

    self:setDelayCloseData()

    if self.panel then
        self.panel:refresh()
    end

    if self:isSigmobAd(name) then
        self:sendInvokeVideoSDKToServer(name, adInfo, placementId, false)
    end

    self.adInfo = nil
end

function InciteManager:onAdsFinished(name, placementId, state, adInfo, adType, customBtnState)
    self:print("onAdsFinished :", name, placementId, state, adType)

    -- 缓存当前播放视频广告信息（打点可能要用）
    self.curPlayingAdInfo = {
        placementId = placementId,
        adType = adType,
    }

    if state == InciteConst.AdsFinishState.kNotCompleted then
        --vivo sdk 3900
        if PlatformConfig:isPlatform(PlatformNameEnum.kBBK)
            and _G.androidLastModifyVersion and _G.androidLastModifyVersion >= 18
        then
            CommonTip:showTip("未观看完整，请稍后重新观看", "negative")
            for name, channel in pairs(self.channels or {}) do
                channel:tryLoadAd("bbk-bugfix")
            end
        else
            CommonTip:showTip("未观看完整，请重新观看", "negative")
        end
    end

    self:getTracer(self.entranceType, self.subEntranceType):notify(InciteEvent.sdk_callback_video_closed, {
        sdkName = name,
        placementId = placementId,
        entry = self.entranceType,
        finishedState = state,
        adInfo = adInfo,
        subEntry = self.subEntranceType,
        playId = UBFGamePlayBridgeInvoker and UBFGamePlayBridgeInvoker:getPlayId(),
        source = self.showPanelSource,
        adv_type = adType,
        customBtnState = customBtnState,
    })

    if self.curPlayInfo then
        local info = self.curPlayInfo

        if name == info.sdk then
            if info.scb then
                info.scb(name, placementId, state, customBtnState)
            end
        end
    end


    self.curPlayInfo = nil
    InciteGameAudioFix.ad_showing = false;

    if InciteGameAudioFix.stop_resume_music_counter > 0 then
        InciteGameAudioFix.stop_resume_music_counter = 0
        safeRunCall(_G.AppResumeGameMusic)
    end
end

function InciteManager:onAdsError(name, code, msg, _entranceType, failedPlacementId, skipShowTip, adType)
    --he_log_error(string.format("name:%s.code:%s.msg:%s", tostring(name), tostring(code), tostring(msg)), true)
    self:print("onAdsError :", name, code, msg)

    self.curPlayingAdInfo = nil

    local dcParam = {
        entry = _entranceType,
        sdkName = name,
        code = code,
        msg = msg,
        adType = adType
    }
    dcParam = self:checkPreLoadDc(dcParam)

    self:getTracer():notify(InciteEvent.sdk_callback_error,dcParam )

    local entranceType = self.entranceType or 'null'
    local placementId = 'null'
    if self.channels and name and self.channels[name] then
        placementId = self.channels[name]:getPlacementId(entranceType)
    end

    if code == InciteConst.AdsError.kDebug then
        return
    end

    sendGrayLogNoStack("onAdsError", "", {
        category = "err_track",
        sub_category = "ads_error",
        bv = _G.fullBundleVersion,
        sdk_name = name,
        entry = self.entranceType,
        placement_id = placementId,
        error_code = tostring(code),
        err_code = tostring(code),
        error_msg = msg,
        })

    local platformEnable = EnvUtil:isMiniGame() or EnvUtil:isAndroid()
    if platformEnable and self.curPlayInfo
        and (self.curPlayInfo.playedPlacementId == failedPlacementId or platformEnable)
    then
        local info = self.curPlayInfo
        if PlatformConfig:isPlatform(PlatformNameEnum.kHuaWei) then
            -- huawei 包忽略播放错误
            if code == InciteConst.AdsError.kPlayError then

                return
            end
        end

        if not skipShowTip then
            if code == InciteConst.AdsError.kVideoNotReady then
                CommonTip:showTip("糟糕，暂时没有视频可看,请稍后尝试！", "negative")
            elseif code == InciteConst.AdsError.kPlayError then
                CommonTip:showTip("播放出错了，请重新观看", "negative")
            end
        end

        if name == info.sdk then
            if info.fcb then
                info.fcb(name, code, msg)
            end
        end
        self.curPlayInfo = nil
    end

    self:sendInvokeVideoSDKErrorToServer(name)
end

function InciteManager:onAdsClicked(name, adType)
    self:print("onAdsClicked :", name, adType)

    self:getTracer(self.entranceType, self.subEntranceType):notify(InciteEvent.sdk_callback_click_download, {
        sdkName = name,
        entry = self.entranceType,
        subEntry = self.subEntranceType,
        playId = UBFGamePlayBridgeInvoker and UBFGamePlayBridgeInvoker:getPlayId(),
        source = self.showPanelSource,
        adv_type = adType,
    })

    local info = self.curPlayInfo
    if info and info.listener and type(info.listener.onClickDownload) == "function" then
        info.listener.onClickDownload(name, adType)
    end
end

-- listener = {
-- onPlayFinished(ads, placementId, state)
-- onPlayError(ads, code, msg)
-- onPlayDidStart()
-- onClickDownload(sdkName, adType)
-- }
function InciteManager:showAdsWithListener(entranceType, listener, subEntranceType, paramEx)
    assert(listener, "listener must not be nil")
    self:showAds(entranceType, listener.onPlayFinished, listener.onPlayError, subEntranceType, paramEx, listener)
end

function InciteManager:showAds(entranceType, onSuccess, onFail, subEntranceType, paramEx, listener)

    if entranceType then
        self.entranceType = entranceType
    end
    self.entranceType = self.entranceType or InciteConst.EntranceType.kPassLevel

    self.subEntranceType = subEntranceType or 1

    self.showPanelSource = 0
    if paramEx and paramEx.bStartPanel2020 then
        self.showPanelSource = 1
    end

    -- 视频没加载好时，等待n秒，n秒内加载好了就自动播放
    local waitDurationWhenVideosNotReady = 5
    if paramEx and paramEx.waitDurationWhenVideosNotReady then
        waitDurationWhenVideosNotReady = paramEx.waitDurationWhenVideosNotReady
    end


    local readySdkId = self:getLoadSucSdk(true, self.entranceType)

    self.curPlayInfo = {
        entranceType = entranceType,
        scb = onSuccess,
        fcb = onFail,
        sdk = readySdkId,
        listener = listener,
    }
    self.readyAd = readySdkId
    if readySdkId then
        self:_playReadyVideo(readySdkId, entranceType)
    else
        if waitDurationWhenVideosNotReady > 0 then
            self:tryLoadAdIfNotReady("no_ad")
            self:_waitUntilVideoIsReady(waitDurationWhenVideosNotReady, entranceType)
        else
            self:onAdsError(readySdkId, InciteConst.AdsError.kVideoNotReady, "no ad", entranceType)
            self:tryLoadAdIfNotReady("no_ad")
        end
    end
end

function InciteManager:getWeekPayLevel()
    local info = self.info
    if info then
        return info.userTagPay or 0
    end
    return 0
end

function InciteManager:getSceneUIVersion(entranceType)
    if self.info and self.info.enableSceneUIMap then
        return self.info.enableSceneUIMap[entranceType] or -1
    end
    return -1
end

function InciteManager:getSceneInfo(entranceType)
    if self.sceneInfos[entranceType] then
        return self.sceneInfos[entranceType]
    end

    local result = require(InciteConfig:getSceneInfoClass(entranceType)).new()

    if self.info and self.info.scenePlayInfoMap then
        local data = self.info.scenePlayInfoMap[tostring(entranceType)] or {}
        result:setData(data)
    end

    self.sceneInfos[entranceType] = result

    return result
end

function InciteManager:isEntryEnable(entranceType, logData)
    local version = self:getSceneUIVersion(entranceType)
    --if not logData then logData = {} end
    --logData["incite_isEntryEnable_version"] = version
    return version and version > 0
end

function InciteManager:isEntryEnableWithUIVersion(entranceType, uiVersion)
    local version = self:getSceneUIVersion(entranceType)
    local configEnabled = (version and version == uiVersion) or EnvUtil:isWinMacSimulator()
    if not configEnabled then return false end

    local function unionTypeVersion(type, _version)
        return type * 10000 + _version
    end

    local result = lua_switch(unionTypeVersion(entranceType, uiVersion)) {
        [unionTypeVersion(InciteConst.EntranceType.kEnergy, 2)] = function()
            local topLevel = self._levelAreaManager:getTopLevelId()
            return topLevel >= 30
        end,
        default = true,
    }

    return result
end

function InciteManager:requestVideoAddEnergy()
    return self.model:requestVideoAddEnergy():next(function(response)
        local data = response:getData()
        self:subCount(InciteConst.EntranceType.kEnergy, data.nextRewardTime)
        return response
    end)
end

function InciteManager:getEntranceType()
    return self.entranceType
end

function InciteManager:getRemaindTime()
    if self:isInDelayCloseCd() then return 0 end

    if self.info and self.info.gotRewardsToday then
        local sceneInfo = self:getSceneInfo(InciteConst.EntranceType.kPassLevel)
        return math.max(sceneInfo:getLimit() - #self.info.gotRewardsToday, 0)
    end

    return 0
end

function InciteManager:getRemainCount(entranceType)
    if not self.info then return 0 end
    if self:isInDelayCloseCd() then return 0 end

    local sceneInfo = self:getSceneInfo(entranceType)
    return sceneInfo:getRemainCount()
end

function InciteManager:getCount(entranceType)
    if not self.info then return 0 end
    if self:isInDelayCloseCd() then return 0 end

    if entranceType == InciteConst.EntranceType.kStartLevel then
        return self:getSceneInfo(entranceType):getRemainCountWithCareAboutCD()
    elseif entranceType == InciteConst.EntranceType.kTree then
        local sceneInfo = self:getSceneInfo(entranceType)
        local nowtime = TimeKit:timeInSec()
        if nowtime >= self.nextDayTime then
            self.nextDayTime = TimeKit:getDayStartTimeByTS(TimeKit:timeInSec()) + 3600 * 24
            sceneInfo:resetPlayedCount()
        end
        return sceneInfo:getRemainCount()
    elseif entranceType == InciteConst.EntranceType.kEnergy then
        ---看视频加精力计数
        local sceneInfo = self:getSceneInfo(entranceType)
        return sceneInfo:getRemainCount()
    elseif entranceType == InciteConst.EntranceType.kEndGame then
        local sceneInfo = self:getSceneInfo(entranceType)
        return sceneInfo:getRemainCountWithCareAboutCD()
    elseif entranceType == InciteConst.EntranceType.kHiddenLevel then
        return 1
    elseif entranceType == InciteConst.EntranceType.kMark2020
            or entranceType == InciteConst.EntranceType.kActivity
            or entranceType == InciteConst.EntranceType.kMergeInfiniteEnergyFree
            or entranceType == InciteConst.EntranceType.kMergeMachineCDFinish
    then
        local sceneInfo = self:getSceneInfo(entranceType)
        return sceneInfo:getRemainCountWithCareAboutCD()
    elseif entranceType == InciteConst.EntranceType.kPassLevelMuitiple then
        local sceneInfo = self:getSceneInfo(entranceType)
        return sceneInfo:getRemainCountWithCareAboutCD()
    elseif entranceType == InciteConst.EntranceType.kPreColorfulStar then
        return self:getVideoColorfulStarBottleCount()
    elseif entranceType == InciteConst.EntranceType.kFaqV2 then
        return 1
    else
        return self:getRemaindTime()
    end
end

function InciteManager:subCount(entranceType, nextTime, subAmount)
    if not self.info then return 0 end

    if self.need_sync then
        self:_refresh()
    end

    if entranceType == InciteConst.EntranceType.kStartLevel then
        local sceneInfo = self:getSceneInfo(entranceType)
        if sceneInfo:getRemainCount() > 0 then
            sceneInfo:increasePlayedCount()
            if self:needFindNextPrePropId() then
                self:findNextPrePropId()
            end
        end

        local config = self:getAIConfigCooldownAndMap(entranceType)
        local nextRewardTime = TimeKit:time() + tonumber(config.cooldown)
        self:setNextRewardTime(entranceType, nextRewardTime)
    elseif entranceType == InciteConst.EntranceType.kEndGame then
        local sceneInfo = self:getSceneInfo(entranceType)
        local subValue = subAmount or 1
        sceneInfo:increasePlayedCount(subValue)
        self:setNextRewardTime(entranceType, nextTime or 0)
    elseif entranceType == InciteConst.EntranceType.kPassLevel
            or entranceType == InciteConst.EntranceType.kPreColorfulStar
            or entranceType == InciteConst.EntranceType.kPassLevelMuitiple
            or entranceType == InciteConst.EntranceType.kTree
            or entranceType == InciteConst.EntranceType.kEnergy
            or entranceType == InciteConst.EntranceType.kMark2020
            or entranceType == InciteConst.EntranceType.kActivity
            or entranceType == InciteConst.EntranceType.kMergeInfiniteEnergyFree
            or entranceType == InciteConst.EntranceType.kMergeMachineCDFinish
    then
        local sceneInfo = self:getSceneInfo(entranceType)
        sceneInfo:increasePlayedCount()
        self:setNextRewardTime(entranceType, nextTime or 0)
    end
end

function InciteManager:getRewardCountdown(entranceType)
    if not self.info then return 0 end
    local sceneInfo = self:getSceneInfo(entranceType)
    return math.floor(tonumber(sceneInfo:getNextRewardTime()) / 1000) - TimeKit:timeInSec()
end

function InciteManager:getNextRewardTime(entranceType)
    if not self.info then return 0 end

    local sceneInfo = self:getSceneInfo(entranceType)
    return sceneInfo:getNextRewardTime()
end

function InciteManager:setNextRewardTime(entranceType, nextTime)
    if not self.info then return end

    local sceneInfo = self:getSceneInfo(entranceType)
    sceneInfo:setNextRewardTime(tonumber(nextTime))
end

function InciteManager:showIncitePanel(entranceType, isAutoPop, isFromPassEnd, onCloseCallback)
    local version = self:getSceneUIVersion(InciteConst.EntranceType.kPassLevel)
    if not version then return end

    local function popout()
        if version >= 1 then
            if not self.panel or self.panel.isDisposed then
                local TurnplatePanelVM = require_debug "amf.feature.ad.incite.view.TurnplatePanelVM"
                self.panel = TurnplatePanelVM:create(self, isFromPassEnd, function()
                    self.panel = nil
                    if self:getRemaindTime() <= 0 then
                        self:removeHomeBtn()
                    end
                    if onCloseCallback then
                        onCloseCallback()
                    end
                    _G.fullScreenSizeManager:screenSizeChanged()
                end)
                self.panel:setLoadResFailCallback(function()
                    CommonTip:showTip(localize("dis.connect.warning.tips"))
                end)
                self.panel:popout()
            end
        else
            self:removeHomeBtn()
            return
        end

    end

    local function show()
        self.entranceType = entranceType
        CCDirector:sharedDirector():getRunningScene():runAction(CCCallFunc:create(popout))
    end

    show()
end

-- 标识本次进关卡是否用了视频buff
function InciteManager:setUseVideoProp(usedVideoProp)
    self.usedVideoProp = usedVideoProp
end

function InciteManager:isStartLevelOpen(items)
    if not items then return false end
    if not self.info then return false end
    if not self.info.prePropId then return false end

    local has = false
    for _,itemId in ipairs(items) do
        if itemId == self.info.prePropId then
            has = true
            break
        end
    end
    if not has then return false end
    return self:isEntryEnable(InciteConst.EntranceType.kStartLevel)
            and self:getReadySdk(nil, InciteConst.EntranceType.kStartLevel)
            and self:getCount(InciteConst.EntranceType.kStartLevel) > 0
end

function InciteManager:getPlayVideoId()
    return self.playVideoId or 'null'
end

function InciteManager:get_cached_enabled_sdk_name()
    return cached_enabled_sdk_name
end

function InciteManager:isPassLevelGroup(targetType)
    if targetType and self.info then
        local passlevelRateReward = self.info.passlevelRateReward
        if passlevelRateReward and passlevelRateReward.passlevelGroup == targetType then
            return true
        end
    end
    return false
end

function InciteManager:getTracer(entranceType, subEntranceType)
    local traceKey

    if entranceType == InciteConst.EntranceType.kEnergy then
        if subEntranceType == 2 then
            traceKey = 'adv_start_energy'
        end
    end

    local InciteTracer = require "amf.feature.ad.incite.dc.InciteTracer"
    return InciteTracer:getTracer(traceKey)
end

function InciteManager:getSupportADVersion()
    local result = {}
    for et, versions in pairs(InciteConst.SupportAdVersion) do
        table.insert(result, {
            scenario = InciteConst.VideoAdAISceneName[et],
            supportedVersion = versions
        })
    end

    result = table.serialize(result)
    return result
end

------------------------------------------------------------
-- 视图
------------------------------------------------------------
function InciteManager:loadRes()
    return _G.amfBean("AssetsUtil"):loadMiniModules({"reward_ad"})
end

function InciteManager:tryShowIcon()
    self:createEntranceBtn(InciteConst.EntranceType.kPassLevel, -2)
end

function InciteManager:createEntranceBtn(entranceType, ads)
    if not self.isInit then return end

    local time = self:getRemaindTime()
    local readySdkId = self:getReadySdk(nil, entranceType)

    print("createEntranceBtn", time, readySdkId)
    if time <= 0 or not readySdkId then
        self:print("time:", time, "readySdkId:",readySdkId)
        return
    end

    if self:isEntryEnable(InciteConst.EntranceType.kPassLevel) and entranceType == InciteConst.EntranceType.kPassLevel then
        self:createHomeSceneBtn(time, ads)
    elseif self:isEntryEnable(InciteConst.EntranceType.kFAQ) and entranceType == InciteConst.EntranceType.kFAQ then
        self:createFQABtn(time)
    else
        self:print("create btn failed, maintenance close this.")
    end
end

function InciteManager:createHomeSceneBtn(time, ads)
    if self.triggerCreateVideo then return end
    InciteEventCenter:dispatch(InciteEvent.SCENE_BUTTON_SHOW_CHANGE, {
        canShow = true,
    })

    self.triggerCreateVideo = true
    self:getTracer():notify(InciteEvent.homescene_icon_appear)

end

function InciteManager:removeHomeBtn()
    InciteEventCenter:dispatch(InciteEvent.SCENE_BUTTON_SHOW_CHANGE, {
        canShow = false,
    })
    self.triggerCreateVideo = false
end

function InciteManager:createFQABtn(time)
    local function createBtn()
        local nextCd = self:getRewardCountdown(InciteConst.EntranceType.kPassLevel)
        local showAnimate = time > 0 and nextCd <= 0
        FAQManager:getInstance():showInciteVideoBtn_animate(time, showAnimate)
        self:handleFAQBtn()
    end
    CCDirector:sharedDirector():getRunningScene():runAction(CCCallFunc:create(createBtn))
end

function InciteManager:handleFAQBtn( )
    local function update()
        local time = self:getRemaindTime() or 0
        local nextCd = self:getRewardCountdown(InciteConst.EntranceType.kPassLevel)
        local showDot = time > 0 and nextCd <= 0
        FAQManager:getInstance():setInciteBtnDotVisible_time(showDot, time)
    end
    self.schedule = Director:sharedDirector():getScheduler():scheduleScriptFunc(update, 20, false)
    update()
end


------------------------------------------------------------
-- 协议
------------------------------------------------------------
function InciteManager:sendInvokeVideoSDKToServer(name, adInfo, placementId, isOnClick)
    local adInfoTable
    if adInfo then
        adInfoTable = table.deserialize(adInfo)
    end

    if adInfoTable then
        local isFix = false
        if self.adInfo == nil then
            self.adInfo = adInfoTable
        else
            isFix = (self.adInfo.loadId ~= adInfoTable.loadId)
        end

        local adTypeName ={
            "激励视频",
            "开屏",
            "",
            "插屏",
        }

        local adInfoParam
		if isOnClick then
			adInfoParam = string.format("%s,%s,%s", adTypeName[adInfoTable.adType], adInfoTable.networkName, placementId)
		elseif isFix then
			adInfoParam = string.format("%s,%s,%s,fixed", adTypeName[adInfoTable.adType], adInfoTable.networkName,placementId)
		end

        if adInfoParam then
            self.model:requestInvokeVideoSDK({
                sdkId = name,
                sceneId = self.entranceType,
                adInfo = adInfoParam,
            })
        end
    end
end

function InciteManager:sendInvokeVideoSDKErrorToServer(ads_name)
    self.model:requestInvokeVideoSDKError({
        sdkId = ads_name,
    })
end

function InciteManager:_getRewardConfig(propSource)
    if not self.info then return {} end

    local sceneInfo = self:getSceneInfo(InciteConst.EntranceType.kPassLevel)
    return {
        timesLimit = sceneInfo:getLimit() or 0,
        timesLimitSig = self.info.timesLimitSig or "",
        propSource = propSource,
    }
end

function InciteManager:receiveLotteryRewards(isFromPassEnd, onSuccess, onFail, onCancel)
    local propSource
    if isFromPassEnd then
        propSource = DcPropHelper:getPropSource(DcFeatureType.kIncentiveVideo, DcSourceType.kPassLotteryWheel)
    else
        propSource = DcPropHelper:getPropSource(DcFeatureType.kIncentiveVideo, DcSourceType.kAdverTurn)
    end

    self.model:requestGetVideoSDKTurntableReward(self:_getRewardConfig(propSource))
    :next(function(response)
        local data = response:getData()
        local reward = data.reward or {}

        if self.info then
            self:subCount(InciteConst.EntranceType.kPassLevel, data.nextRewardTime)
            if data.lastRewardTime then
                self.info.lastRewardTime = data.lastRewardTime
            end
            table.insert(self.info.gotRewardsToday, reward)
        end
        self:saveState()

        if isFromPassEnd then
            self:getTracer():notify(InciteEvent.passlevel_wheel_reward,{
                itemId = reward.itemId,
                num = reward.num,
            })
        else
            self:getTracer():notify(InciteEvent.homescene_rewarded_success, {
                itemId = reward.itemId,
                num = reward.num,
            })
        end

        if onSuccess then
            onSuccess({reward})
        end
    end, function(response)
        if not isFromPassEnd then
            self:getTracer():notify(InciteEvent.homescene_rewarded_exception)
        end
        if onFail then onFail(response) end
    end)

    if not isFromPassEnd then
        self:getTracer():notify(InciteEvent.homescene_click_rotate_button)
    end
end

------------------------------------------------------------
-- 激励视频加二步升级
------------------------------------------------------------
function InciteManager:getAddTwoStepComboInfo()
	if not self.addTwoStepComboInfoData then
		local infoData
		if self.getExtraInfo and _G.InciteConst and _G.InciteConst.ExtraType and _G.InciteConst.ExtraType.ADDTWOSTEP_VideoCombo then 
			infoData = self:getExtraInfo(_G.InciteConst.ExtraType.ADDTWOSTEP_VideoCombo)
		else
			if self.info and self.info.upBean then
				local data = self.info.upBean or {}
				infoData = AddTwoStepComboInfo:create()
				infoData:setData(data)
				-- printx(11, "===== addTwoStepComboInfoData - from user")
			end

            --
--
--
--
--
--

		end

		self.addTwoStepComboInfoData = infoData
	end

	if self.addTwoStepComboInfoData then
		self.addTwoStepComboInfoData:checkResetOnPassDay()	-- videoSDKInfo、self.info 的刷新都不可控，只能每次自己检测了……

		-- printx(11, "===== addTwoStepComboInfoData:", tts(self.addTwoStepComboInfoData))
		return self.addTwoStepComboInfoData
	end
	return nil
end

------------------------------------------------------------
-- 智能广告 个性化推荐
------------------------------------------------------------
function InciteManager:getSmartAdEnabled()
    if self._shimingManager:isforbiddenForJuvenile() then
        return false
    end

    if self._smartAdEnabled == nil then
        self._smartAdEnabled = LocalDB:getBool("isSmartAdEnabled", true)
    end
    return self._smartAdEnabled
end

function InciteManager:setSmartAdEnabled(isEnabled)
    if isEnabled ~= self:getSmartAdEnabled() then
        self._smartAdEnabled = isEnabled
        LocalDB:setBool("isSmartAdEnabled", isEnabled)
    end
end

function InciteManager:getRecommendEnabled()
    if self._shimingManager:isforbiddenForJuvenile() then
        return false
    end

    if self._recommendEnabled == nil then
        self._recommendEnabled = LocalDB:getBool("isRecommendEnabled", true)
    end
    return self._recommendEnabled
end

function InciteManager:setRecommendEnabled(isEnabled)
    if isEnabled ~= self:getRecommendEnabled() then
        self._recommendEnabled = isEnabled
        LocalDB:setBool("isRecommendEnabled", isEnabled)
    end
end


------------------------------------------------------------
-- AI
------------------------------------------------------------
function InciteManager:isAiGroup()
    local ai_config = self:getAIConfig() or {}
    return  ai_config.adActualGroupTag == 'ai'
end

function InciteManager:getAIConfig()
    local ai_config = {}

    if self.info then
        ai_config = self.info.ai_config or {}
    end

    if not ai_config.scenarioConfigMap then
        ai_config.scenarioConfigMap = {}
    end

    return ai_config
end

function InciteManager:getAIConfigCooldownAndMap(entranceType)
    local scenarioConfigMap = self:getAIConfig().scenarioConfigMap
    local config = scenarioConfigMap[tostring(entranceType)] or {}

    if not config.cooldown then
        config.cooldown = 0
    end
    if not config.limit then
        config.limit = 0
    end

    if not config.version then
        config.version = 0
    end

    if config.display == nil then
        config.display = 0
    end

    return config
end


------------------------------------------------------------
-- 事件
------------------------------------------------------------
function InciteManager:onSystemEnterForeground()
    if not self.isInit then return end

    --vivo 需要重新加载广告，因为广告在home回来的时候会被干掉
    if _G.androidLastModifyVersion and _G.androidLastModifyVersion >= 18 then
        if self.curPlayInfo and not (PlatformConfig:isPlatform(PlatformNameEnum.kBBK)) then return end
    else
        if self.curPlayInfo then return end
    end
    if not self:hasVideoChance() then return end

    if EnvUtil:isIOS() then
        if self:isNeedReloadiOSAds() then
            if self._bugfixTimerId then
                cancelTimeOut(self._bugfixTimerId)
                self._bugfixTimerId = nil
            end

            self._bugfixTimerId = setTimeOut(function()
                if self:isNeedReloadiOSAds() then
                    for name, channel in pairs(self.channels or {}) do
                        channel:onEnterForground()
                    end
                end
                self._bugfixTimerId = nil
            end, 10)
        end
    else
        for name, channel in pairs(self.channels or {}) do
            channel:onEnterForground()
        end
        if _G.androidLastModifyVersion and _G.androidLastModifyVersion >= 18 then
            setTimeOut(function()
                if self.panel then
                    self.panel:refresh()
                end
            end, 0.1)
        end
    end
    self:_refresh()
end

function InciteManager:onReceiveTransaction(event)
    if event:getName() ~= TransactionEvent.AD then return end
    local data = event:getData()
    if not data then return end

    if data.type == "dc" then
        local entranceType = nil
        local subEntranceType = nil
        if data.info then
            entranceType = data.info.entranceType
            subEntranceType = data.info.subEntranceType
            data.info.entranceType = nil
            data.info.subEntranceType = nil
        end
        self:getTracer(entranceType, subEntranceType):notify(data.action, data.info)
    else
        self.lastClickTime = TimeKit:timeInMillis()
        if data.action == "play" then
            local onSuccess = data.info.onSuccess
            local onFail = data.info.onFail
            if data.info.listener then
                onSuccess = onSuccess or data.info.listener.onPlayFinished
                onFail = onFail or data.info.listener.onPlayError
            end
            self:showAds(
                data.info.entranceType, onSuccess, onFail,
                data.info.subEntranceType, data.info.paramEx, data.info.listener
            )
        end
    end
end

function InciteManager:isLocked()
    --抖音小游戏广告出现有延迟，防止接口重复调用
    if self.lastClickTime and EnvUtil:isDYMiniGame() then
        if (TimeKit:timeInMillis() - self.lastClickTime) < 3000 then
            return true
        end
    end
end

-- 需要改成事件
function InciteManager:onEnterFQA()
    if not self.isInit then return end
    self.entranceType = InciteConst.EntranceType.kFAQ
    self:createEntranceBtn(InciteConst.EntranceType.kFAQ)
end

-- 需要改成事件
function InciteManager:onExitFAQ()
    if self.schedule then
        Director:sharedDirector():getScheduler():unscheduleScriptEntry(self.schedule)
        self.schedule = nil
    end
end

function InciteManager:onPassLevel(data)
    data = data.data
    if data and data.isWin then
        if self.usedVideoProp then
            self.usedVideoProp = false
            return
        else
            if self:needFindNextPrePropId() then
                self:findNextPrePropId()
            end
        end
    end
end


------------------------------------------------------------
-- 额外业务数据
------------------------------------------------------------
function InciteManager:getDataByChain(keyChain)
    if not self.info then return nil end
    local keys = string.split(keyChain, ".")
    local ret = self.info
    local keyNum = #keys
    for i = 1, keyNum do
        local key = keys[i]
        if i == keyNum then
            local data = ret[key]
            return data
        elseif type(ret[key]) ~= 'table' then
            ALog.error("InciteManager:getDataByChain() error, keyChain not found ", keyChain)
            break
        end
        ret = ret[key]
    end
end

function InciteManager:getExtraInfo(entranceType)
    if not self.extraInfos[entranceType] then
        local ExtraInfoConfig = InciteConfig:getExtraConfig(entranceType)
        if not ExtraInfoConfig then return end

        local data = self:getDataByChain(ExtraInfoConfig.keyChain)
        if ExtraInfoConfig.classPath then
            local infoData = require(ExtraInfoConfig.classPath):create()
            if data then
                infoData:setData(data)
            else
                --
--
--
--
--

            end
            data = infoData
        end
        self.extraInfos[entranceType] = data
    end

    if self.extraInfos[entranceType] and self.extraInfos[entranceType].checkResetOnPassDay then
        self.extraInfos[entranceType]:checkResetOnPassDay()  -- videoSDKInfo、self.info 的刷新都不可控，只能每次自己检测了……
    end
    return self.extraInfos[entranceType]
end

-- 获取空白的相应ExtraInfo，关卡内还原数据用
function InciteManager:getBlankExtraInfo(entranceType)
    local ExtraInfoConfig = InciteConfig:getExtraConfig(entranceType)
    if not ExtraInfoConfig then return end

    local infoData = require(ExtraInfoConfig.classPath):create()
    return infoData
end

------------------------------------------------------------
-- 激励视频彩星集分瓶相关
------------------------------------------------------------
InciteManager.VIDEO_PRECOLORFULSTAR_VERSION = 1

local function toActualTopLevel(level)
    level = tonumber(level) or 0
    if level <= 0 then
        local configTopLevel = _G.amfBean("LevelUnLockManager"):getLocalMaxOpenLevel()
        level = configTopLevel + 1 + level
    end
    return level
end

function InciteManager:isVideoColorfulStarBottleEnabled(ts)
    if not self:isEntryEnable(InciteConst.EntranceType.kPreColorfulStar) then return false, 1 end

    local videoColorfulStarBottleInfo = self:getExtraInfo(InciteConst.EntranceType.kPreColorfulStar)
    if type(videoColorfulStarBottleInfo) ~= "table" then return false, 2 end

    local requiredVersion = videoColorfulStarBottleInfo.version or 0
    if requiredVersion > self.VIDEO_PRECOLORFULSTAR_VERSION then return false, 3 end

    local startTime = tonumber(videoColorfulStarBottleInfo.startTime) or 0
    local endTime = tonumber(videoColorfulStarBottleInfo.endTime) or 0
    ts = ts or TimeKit:timeInMillis()
    if ts < startTime or ts >= endTime then return false, 4 end

    local minTopLevel = toActualTopLevel(videoColorfulStarBottleInfo.minLevel)
    local maxTopLevel = toActualTopLevel(videoColorfulStarBottleInfo.maxLevel)
    local topLevelId = self._levelAreaManager:getTopPassedMainLevelId() + 1
    if topLevelId < minTopLevel or topLevelId > maxTopLevel then return false, 5 end

    local rewards = self:getVideoColorfulStarBottleRewards()
    if table.size(rewards) == 0 then return false, 6 end

    if not self:getReadySdk(nil, InciteConst.EntranceType.kPreColorfulStar) then return false, 7 end

    return true
end

function InciteManager:getVideoColorfulStarBottleRewards()
    local videoColorfulStarBottleInfo = self:getExtraInfo(InciteConst.EntranceType.kPreColorfulStar)
    if type(videoColorfulStarBottleInfo) ~= "table" then return {} end

    return videoColorfulStarBottleInfo.rewardList or {}
end

function InciteManager:getVideoColorfulStarBottleCount()
    if not self.info then return 0 end
    local sceneInfo = self:getSceneInfo(InciteConst.EntranceType.kPreColorfulStar)
    if sceneInfo:getNextRewardTime() > TimeKit:time() then
        return 0
    end

    local videoColorfulStarBottleInfo = self:getExtraInfo(InciteConst.EntranceType.kPreColorfulStar)
    if type(videoColorfulStarBottleInfo) ~= "table" then return 0 end
    local limit = tonumber(videoColorfulStarBottleInfo.maxTimes) or 0
    if limit <= 0 then
        return 1
    end

    return math.max(limit - sceneInfo:getPlayedCount(), 0)
end

function InciteManager:setVideoColorfulStarBottlePlayedCountMax()
    if not self.info then return 0 end

    local sceneInfo = self:getSceneInfo(InciteConst.EntranceType.kPreColorfulStar)
    sceneInfo:setPlayedCountMax()
    sceneInfo:setNextRewardTime(0)
end



function InciteManager:getDelayCloseFlag()

	if self.info and self.info.newDelayCloseClientBean and self.info.newDelayCloseClientBean.bufferEndTimestamp then
		local endTime = tonumber(self.info.newDelayCloseClientBean.bufferEndTimestamp) 

		if self.delayCloseInfo and self.delayCloseInfo.randomList then
			local maxHour = 0
			for k, v in pairs(self.delayCloseInfo.randomList) do
				if v.maxHour > maxHour then
					maxHour = v.maxHour
				end
			end

			-- ULog( "maxHour ".. maxHour)
			endTime = endTime + maxHour * 3600 * 1000
		end
		-- ULog( "endTime:  ".. endTime)
        
		if TimeKit:timeInMillis() < tonumber(endTime) then
			return 1
		end
	end

	return 2
end

function InciteManager:getEnableFlag()

	if self.info and self.info.enableScenes and #self.info.enableScenes > 0 then
		return 1
	end
	
	return 2
end



function InciteManager:setVideoButton(val)
    self._videoButton = val
end



function InciteManager:adGuideCheckCondition(evtData)
    local isLevelPassed = evtData.isLevelPassed
    local levelId = evtData.levelId

    ---最新关胜利才弹
    if not isLevelPassed or levelId ~= _G.getTopPassedLevelId() then
        --UWarning("adGuideCheckCondition_0")
        return false
    end

    if not self.triggerCreateVideo then
        --UWarning("adGuideCheckCondition_01")
        return false
    end

    local enabled = MaintenanceManager:getInstance():isEnabledInGroup("h5_turntable", "3times_guide")
            or MaintenanceManager:getInstance():isEnabledInGroup("h5_turntable", "5times_guide")

    if not enabled then
        --UWarning("adGuideCheckCondition_02")
        return false
    end

    if self:isInDelayCloseStrategy() then
        --UWarning("adGuideCheckCondition_03")
        return false
    end

    if  _G.amfBean("AutoPopupMgr"):ignoreForTopLevelPlayer() then -- 周五晚19:00~23:00，对头部top30打新关的玩家屏蔽
        --UWarning("adGuideCheckCondition_04")
        return false
    end

    local lastLoginTime = _G.amfBean("AccountManager"):getLastLoginTime()

    if lastLoginTime  and not self._alreadyPopLastLoginAd then
        local time = TimeKit:time()
        if time - lastLoginTime >=  60 * 60 * 24 * 180 * 1000 then
            --UWarning("adGuideCheckCondition_05")
            return true
        end
    end

    local isAlreadyPop = _G.amfBean("ServerCacheManager"):getCache("ad_guide_popup")
    if isAlreadyPop ~= nil then
        --UWarning("adGuideCheckCondition_06")
        return false
    end
    --UWarning("adGuideCheckCondition_07")
    return true
end

function InciteManager:onActEnterStage4(evt)
    local evtData = evt.data
    --UWarning("adGuide onActEnterStage4")
    if not self:adGuideCheckCondition(evtData) then
        return
    end

    self._alreadyPopLastLoginAd = true

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.AD_GUIDE)
    end
    local function creator()
        --UWarning("ad_____OnActEnterStage4_08")
        self:showGuide(onHandleOver)
    end
    --UWarning("adOnActEnterStage4_07")
    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.AD_GUIDE, creator)
end

function InciteManager:showGuide(callback)
    local data = {
        category = 'stimulate_video',
        sub_category = 'turntable_guide',
    }
    DcUtil:UserTrack(data)

    _G.amfBean("ServerCacheManager"):setCache("ad_guide_popup",true)
    local HeGuide = require 'amf.middleware.ui.kit.component.HeGuide'
    local heGuide = HeGuide:create(nil, true, true)
    local contentList = {
        {ttf = "免费", color =  "b2714aff"},
        {ttf = "风车币", color =  "00a5c8ff"},
        {ttf = "派送中，快来试试手气！",color =  "b2714aff"},
    }

    local npc = heGuide:showNpc2(contentList)
    if self._videoButton and not self._videoButton.isDisposed then
        --heGuide:addAccurateGuide(self._videoButton,{self._videoButton})
        heGuide:addAccurateGuide(heGuide,{self._videoButton})
        heGuide:showGuideHand(self._videoButton, {x = 0, y = 0},1,0)
        local wPos = self._videoButton:getPositionInWorldSpace()
        local visibleSize = CCDirector:sharedDirector():getVisibleSize()
        local moveY = 230 ---icon在屏幕中间以下

        if wPos.y >= visibleSize.height / 2 then
            moveY = -320 --icon在屏幕中间以上
        end
        npc:setPositionY(wPos.y + moveY)
    end

    heGuide:setEndCall(function(worldPos)
        if self._videoButton and not self._videoButton.isDisposed then
            if self._videoButton:hitTestPoint(worldPos, true) then
                self:showIncitePanel(InciteConst.EntranceType.kPassLevel,false,nil,callback)
            else
                safeRunCall(callback)
            end
        else
            safeRunCall(callback)
        end
    end)
end

function InciteManager:checkPreLoadDc(dcParam)
    if not self:canPreLoadAds() then
        local curPlayInfo = self:getCurPlayInfo()
        if curPlayInfo and curPlayInfo.entranceType  then
            dcParam.adv_location = curPlayInfo.entranceType
        else
            dcParam.adv_location = -1
        end
    end
    return dcParam
end


function InciteManager:getCurPlayInfo()
    return self.curPlayInfo
end

function InciteManager:canPreLoadAds()
    --printx(43,"self.info =" , tts(self.info))
    if self.info and self.info.preLoadClose then
        return  false
    end

    return true
end


function InciteManager:getDcParam_AdLeftTimes()
    -- body

    local ret = ""

    if self.info then
        local keys = {
            InciteConst.EntranceType.kPassLevel,
            InciteConst.EntranceType.kStartLevel,
            InciteConst.EntranceType.kTree,
            InciteConst.EntranceType.kEnergy,
            InciteConst.EntranceType.kEndGame,
        }

        local values = {}
        for _, key in ipairs(keys) do
            table.insert(values, self:getCount(key) or 0)
        end
        ret = table.concat(values, "_")
    end

    return ret
end


function InciteManager:loadSplashAd()
	if PlatformConfig:isPlatform(PlatformNameEnum.kHE) or PlatformConfig:isPlatform(PlatformNameEnum.kDouYinLh) then
		local SplashAdManager = require "amf.feature.ad.splash.system.android.SplashAdManager"
		SplashAdManager:registerEvent()
	end
end

return InciteManager
