local PersonalCenterManager = class("PersonalCenterManager")
local deferred = require "amf.script.sugar.deferred"
local PersonalCenterEventCenter = require "amf.feature.personalhub.personalcenter.event.PersonalCenterEventCenter"
local FenceEventCenter = require "amf.middleware.fence.event.FenceEventCenter"
local PlayerStatusEventCenter = require "amf.feature.personalhub.playerstatus.event.PlayerStatusEventCenter"
local MainSceneEventCenter = require "amf.feature.mainscene.core.event.MainSceneEventCenter"
local HeadImageObserver = require "amf.feature.personalhub.namecard.decoration.headimage.logic.HeadImageObserver"
require "amf.feature.personalhub.personalcenter.config.PersonalCenterConst"

local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local IllegalWordFilterUtil = require "amf.middleware.ui.util.IllegalWordFilterUtil"
local TakePhotoUtil = require "amf.middleware.ui.util.TakePhotoUtil"

local PersonalCenterHeadFramePart = require "amf.feature.personalhub.personalcenter.system.common.PersonalCenterHeadFramePart"
local PersonalCenterFlowerSkinPart = require "amf.feature.personalhub.personalcenter.system.common.PersonalCenterFlowerSkinPart"
local PersonalCenterNamecardBgPart = require "amf.feature.personalhub.personalcenter.system.common.PersonalCenterNamecardBgPart"
local PersonalCenterNicknameDecoPart = require "amf.feature.personalhub.personalcenter.system.common.PersonalCenterNicknameDecoPart"

function PersonalCenterManager:ctor()
    self._assetsUtil = nil
    self._iconManager = nil
    self._levelAreaManager = nil
    self._propManager = nil
    self._autoPopupMgr = nil
    self._userManager = nil
    self._profileManager = nil
    self._fenceManager = nil
    self._friendManager = nil
    self._metaManager = nil
    self._headImageSyncManager = nil
    self._settingManager = nil
    self._accountManager = nil
    self._serverCacheManager = nil
    self._headFrameManager = nil
    self._updateProfileManager = nil
    self._networkStatusManager = nil
    self._dailyDataManager = nil

    self._model = nil
    self._globalResLoaded = false
    self._iconTouchLock = false
    self._observers = {}
    self._requiringUserInfo = false
    self._needAuthor = false
    self._photoMode = false
end

function PersonalCenterManager:setProfileManager(profileManager)
    self._profileManager = profileManager
end

function PersonalCenterManager:setUserManager(userManager)
    self._userManager = userManager
end

function PersonalCenterManager:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
end

function PersonalCenterManager:setPropManager(propManager)
    self._propManager = propManager
end

function PersonalCenterManager:setLevelAreaManager(mgr)
    self._levelAreaManager = mgr
end

function PersonalCenterManager:setIconManager(iconManager)
    self._iconManager = iconManager
end

function PersonalCenterManager:setAssetsUtil(assetsUtil)
    self._assetsUtil = assetsUtil
end

function PersonalCenterManager:setFenceManager(fenceManager)
    self._fenceManager = fenceManager
end

function PersonalCenterManager:setFriendManager(friendManager)
    self._friendManager = friendManager
end

function PersonalCenterManager:setMetaManager(metaManager)
    self._metaManager = metaManager
end

function PersonalCenterManager:setHeadImageSyncManager(headImageSyncManager)
    self._headImageSyncManager = headImageSyncManager
end

function PersonalCenterManager:setSettingManager(settingManager)
    self._settingManager = settingManager
end

function PersonalCenterManager:setAccountManager(accountManager)
    self._accountManager = accountManager
end

function PersonalCenterManager:setServerCacheManager(serverCacheManager)
    self._serverCacheManager = serverCacheManager
end

function PersonalCenterManager:setHeadFrameManager(headFrameManager)
    self._headFrameManager = headFrameManager
end

function PersonalCenterManager:setUpdateProfileManager(updateProfileManager)
    self._updateProfileManager = updateProfileManager
end

function PersonalCenterManager:setNetworkStatusManager(networkStatusManager)
    self._networkStatusManager = networkStatusManager
end

function PersonalCenterManager:setDailyDataManager(dailyDataManager)
    self._dailyDataManager = dailyDataManager
end

function PersonalCenterManager:initialize()
    self.headFramePart = PersonalCenterHeadFramePart:create(self)
    self.flowerSkinPart = PersonalCenterFlowerSkinPart:create(self)
    self.namecardBgPart = PersonalCenterNamecardBgPart:create(self)
    self.nicknameDecoPart = PersonalCenterNicknameDecoPart:create(self)

    self._model = require("amf.feature.personalhub.personalcenter.model.Model"):create()
    self._model:requestGetNameCardConfig()


    -- _G.amfEC:registerFeature(self)
    PersonalCenterEventCenter:registerFeature(self)

    FenceEventCenter:register(FenceEvent.REVIEW_INFO_UPDATED, self.onReviewInfoUpdated, self)

    PlayerStatusEventCenter:register(PlayerStatusEvent.PLAYER_STATUS_UPDATED, self.onPlayerStatusUpdated, self)
    PlayerStatusEventCenter:register(PlayerStatusEvent.FRIEND_STATUS_VIEWED, self.onFriendStatusViewed, self)

    IconEventCenter:register(IconEvent.ICON_SYSTEM_READY, self.updateIcon, self)
    IconEventCenter:register(IconEvent.ICON_POOL_EXPAND, self.onIconPoolExpand, self)
    IconEventCenter:register(IconEvent.ICON_POOL_HIDE, self.onIconPoolHide, self)

    self:checkNeedPrivacyAuthorized():next(function(needAuthor)
        self:updateIcon()
    end)
end

function PersonalCenterManager:addObserver(observer)
    table.insert(self._observers, observer)
end

function PersonalCenterManager:removeObserver(observer)
    for i,v in ipairs(self._observers) do
        if v == observer then
            table.remove(self._observers, i)
            break
        end
    end
end

function PersonalCenterManager:notify( eventName, ... )
    PersonalCenterEventCenter:dispatch( eventName, ... )
end

------------------------ 业务逻辑 ----------------------------

function PersonalCenterManager:isEnabled()
    return self._model --and self._model:getValue("isFromServer")
end

-- 一般不传，除非你知道在干什么
function PersonalCenterManager:isMe(info)
    local info = info or self._model:peekTopInfo()
    if info and info.getProfile then
        local profile = info:getProfile() or {}
        return profile.uid == self._profileManager:getUid()
    end

    return false
end

function PersonalCenterManager:isMeId(id, isXxlId)
    local meId = isXxlId and self._profileManager:getXxlId() or self._profileManager:getUid()
    return id == meId
end

function PersonalCenterManager:getCurNamecardInfo()
    return self._model:peekTopInfo()
end

function PersonalCenterManager:getDataCount()
    return self._model:countInfoStack()
end

------------------------ 协议 ----------------------------------

function PersonalCenterManager:requestGetThumbsPanelInfo()
    local params = {}

    local promise = deferred.new()

    self._model:requestGetThumbsPanelInfo(params):next(function(response)
        local data = response:getData()
        promise:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

-- 回赞别人
function PersonalCenterManager:requestAutoThumbsUpUser(beThumbsUpXxlId)
    if self:checkReachDailyLikeLimit() then
        return self:createDailyLikeLimitResp()
    end
    local params = {beThumbsUpXxlId = beThumbsUpXxlId}

    local promise = deferred.new()

    self._model:requestAutoThumbsUpUser(params):next(function(response)
        local data = response:getData()
        promise:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

function PersonalCenterManager:requestGetNameCardChildInfo(type)
    local promise = deferred.new()

    local nameCardInfo = self:getCurNamecardInfo()
    if not nameCardInfo or not nameCardInfo.getProfile then
        promise:reject()
        return promise
    end

    local xxlId = nameCardInfo:getProfile().xxlId

    self._model:requestGetNameCardChildInfo(xxlId, type):next(function(response)
        local data = response:getData()
        promise:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

function PersonalCenterManager:requestUnionGetNameCardInfo(xxlId, withReviewInfo)
    local promise = deferred.new()
    self._model:requestUnionGetNameCardInfo(xxlId, withReviewInfo):next(function(response)
        local data = response:getData()
        promise:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

function PersonalCenterManager:requestGetNameCardInfo(uid, withReviewInfo)
    local promise = deferred.new()
    self._model:requestGetNameCardInfo(uid, withReviewInfo):next(function(response)
        local data = response:getData()
        promise:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

-- 更新profile信息
function PersonalCenterManager:requestLocationRankInfoCheckUpdate()
    local promise = deferred.new()

    self._model:requestLocationRankInfoCheckUpdate():next(function(response)
        local data = response:getData()
        promise:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

-- 更新profile信息
function PersonalCenterManager:requestUpdateProfile(operations, customProfile)
    if not operations then
        operations = {}
    end
    local requestOperations = {}
    for i,v in ipairs(operations) do
        local key = v.key
        local op = v.op

        if ((key == "name" and op == "update") or (key == "signature" and op == "update"))
            and self._fenceManager:isV2Enabled() then
            -- do nothing
        else
            table.insert(requestOperations, v)
        end
    end

    local promise = deferred.new()

    self._model:requestUpdateProfile({
        operations = requestOperations,
        customProfile = customProfile,
        version = 1,
    }):next(function(response)
        local data = response:getData()

        self:handleProfileOperations(operations, customProfile)
        self:notify(PersonalCenterEvent.PROFILE_UPDATED, self._profileManager:getXxlId())

        promise:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

function PersonalCenterManager:updateUnifyLocation(locationId,location,adcode,funcId,successCallback, failCallback, cancelCallback,extra)

    self._model:requestUpdateUnifyLocation({
        locationId = locationId,
        location = location,
        adcode = adcode,
        id = funcId,
        forceSame = extra and extra.forceSame,
    }):next(function(response)
        printx(44, "adcode",adcode)
        self._profileManager:setProfileValue("locationId", locationId)
        self._profileManager:setProfileValue("location", location)
        self._profileManager:setProfileValue("adcode", adcode)
        self:updateLocationUpdateTime()
        safeRunCall(successCallback)
    end, function(response)
        CommonTip:showErrorTip(response)
        if not response:isCancel() then
            safeRunCall(failCallback)
        else
            safeRunCall(cancelCallback)
        end
    end)
end

function PersonalCenterManager:handleProfileOperations(operations, customProfile)
    local cardInfos = self._model:getNameCardInfoStack()
    local info = table.find(cardInfos, function(info)
        return self:isMe(info)
    end)
    local profile = info and info.getProfile and info:getProfile()

    if customProfile then
        self._profileManager:setExtendValue("customProfile", customProfile)
        if profile then
            profile.customProfile = true
        end
    end

    for i,v in ipairs(operations) do
        local key = v.key
        local op = v.op
        local params = v.params

        if key == "name" and op == "update" then
            self._profileManager:setProfileValue("name", HeDisplayUtil:urlEncode(params))
            if profile then
                profile.name = params
            end
        elseif key == "signature" and op == "update" then
            -- self._profileManager:setProfileValue("signature", params)
            if profile then
                profile.signature = params
            end
        elseif key == "location" and op == "update" then
            local data = table.deserialize(params)
            self._profileManager:setProfileValue("location", data.loc)
            self._profileManager:setProfileValue("locationId", data.locId)
            self._profileManager:setProfileValue("adcode", data.adcode)

            if profile then
                profile.location = data.loc
                profile.locationId = data.locId
                profile.adcode = data.adcode
            end

            self:updateLocationUpdateTime()
        elseif key == "birthDate" and op == "update" then
            self._profileManager:setBirthDate(params)
            if profile then
                profile.birthDate = params
            end
        elseif key == "gender" and op == "update" then
            self._profileManager:setGender(params)
            if profile then
                profile.gender = params
            end
        -- elseif key == "fileIds" and op == "update" then 目前缓存的已经改过了，profilemanager又不关心，所以无视
        elseif key == "headUrl" and op == "update" then
            self._profileManager:setProfileValue("headUrl", params)
            if profile then
                profile.headUrl = params
            end
        elseif key == "snsDetail" and op == "delSnsHead" then
            local snsPlatform = table.deserialize(params).snsPlatformEnum
            self._accountManager:updateSnsInfo(snsPlatform, nil, nil, "", "")
            if profile then
                profile.snsMap = self._accountManager:getSnsMap(false)
            end
        elseif key == "snsDetail" and op == "update" then
            local snsInfo = table.deserialize(params)
            self._accountManager:updateSnsInfo(snsInfo.snsPlatformEnum, snsInfo.snsName, snsInfo.name, snsInfo.headUrl, nil, true)

            if profile then
                profile.snsMap = self._accountManager:getSnsMap(false)
            end
        elseif key == "secret" and op == "update" then
            local secretV2 = self._profileManager:getProfileValue("secretV2")

            local curSecretV2 = table.deserialize(params)
            if curSecretV2 then
                for k,v in pairs(curSecretV2) do
                    secretV2[k] = v
                end
            end
            self._profileManager:setProfileValue("secretV2", secretV2)
            if profile then
                profile.secretV2 = secretV2
            end
        end
    end
    if info and profile then
        info:setProfile(profile)
    end
end

--使用已经过审的cdn头像
function PersonalCenterManager:requestUseReviewedCDNHeadUrl(snsPlatform, cdnHeadUrl, successCallback, failCallback)
    local promise = deferred.new()

    self._model:requestUseReviewedCdnHeadUrl({
        snsPlatform = snsPlatform,
        cdnHeadUrl = cdnHeadUrl,
    }):next(function(response)
        local data = response:getData()

        if data.code == 0 then
            self._profileManager:setProfileValue("headUrl", data.headUrl)
            self._profileManager:setProfileValue("originHeadUrl", cdnHeadUrl)
            local profile = self:getProfile()
            if self:isMe() and profile then
                profile.headUrl = data.headUrl
                profile.originHeadUrl = cdnHeadUrl
            end
            if profile and not table.isEmpty then
                self:notify(PersonalCenterEvent.PROFILE_UPDATED, profile.xxlId)
            end

            self:notify(PersonalCenterEvent.CHANGE_HEAD_IMAGE, data.headUrl)
            self:notifyHeadImageObserver()

            safeRunCall(successCallback)
            promise:resolve(data)
        else
            if data.reviewState then
                local entry = self:_getHeadImageReviewEntry(cdnHeadUrl)
                if not entry then return nil end
                entry.state = data.reviewState
                self:notify(PersonalCenterEvent.REVIEW_INFO_UPDATED)
            end
            safeRunCall(failCallback)
            promise:reject()
        end
    end, function()
        safeRunCall(failCallback)
        promise:reject()
    end)

    return promise
end

------------------------ profileUpdate ----------------------------
function PersonalCenterManager:setMyHeadImageUrl(val)
    val = val or ""
    self:requestUpdateProfile({{
        key = "headUrl",
        op = "update",
        params = tostring(val),
    }}, true):next(function()
        -- self._profileManager:setProfileValue("headUrl", val)
        if self:isMe() then
            local info = self:getNamecardInfo()
            if info and info.getProfile then
                local profile = info:getProfile()
                profile.headUrl = val
                info:setProfile(profile)
            end
        end
        self:notify(PersonalCenterEvent.CHANGE_HEAD_IMAGE, val)
        self:notifyHeadImageObserver()
    end)
end

function PersonalCenterManager:setNickNameType(type)
    require "amf.feature.personalhub.namecard.decoration.personalnickname.logic.NicknameType"
    type = type or _G.NicknameType.kDefault

    local params = type
    if params >= _G.NicknameType.kDefault then
        params = self._propManager:getNicknameId(type)
    end

    self:requestUpdateProfile({{
        key = "namePattern",
        op = "update",
        params = tostring(params),
    }}, true):next(function()
        local expire = 0

        if self:isMe() then
            local info = self:getNamecardInfo()
            if info and info.getProfile then
                local profile = info:getProfile()
                expire = self:_getNamePatterExpire(profile, params)
                profile.namePatternId = params
                profile.namePatternExpire = expire
                info:setProfile(profile)
            end
        end
        self._profileManager:setProfileValue("namePatternId", params)
        self._profileManager:setProfileValue("namePatternExpire", expire)
        self:notify(PersonalCenterEvent.CHANGE_NICK_NAME_DECO, type)
    end)
end

function PersonalCenterManager:setVineSkinType(skinId, callback, dontQueryFlowerChange)
    require "amf.feature.personalhub.namecard.userdecotype.UserDecoMgr"
    require "amf.feature.personalhub.namecard.decoration.vineskin.logic.VineSkinType"
    require "amf.feature.personalhub.namecard.decoration.levelflower.logic.FlowerSkinType"
    local FlowerSkin = require "amf.feature.personalhub.namecard.decoration.levelflower.FlowerSkin"
    skinId = tonumber(skinId) or VineSkinType.kDefault

    local callbackCalled = false
    local function finish(success, err)
        if callbackCalled then return end
        callbackCalled = true
        if success then
            CommonTip:showTip("更换藤蔓装扮成功", "positive")
        end
        safeRunCall(callback, success, err)
    end

    local vineSkinManager = _G.amfBean("VineSkinManager")
    local flowerId = FlowerSkin:getUserSkinType()

    local function afterSkinChanged()
        UserDeco:setDecoUsing(UserDecoType.kVineSkin, skinId)
        self:setUsingDeco(UserDecoType.kVineSkin, skinId)

        local bigVineSkinActManager = _G.amfBean("BigVineSkinActManager")
        if bigVineSkinActManager and bigVineSkinActManager.updateTrialUsingSkinState then
            bigVineSkinActManager:updateTrialUsingSkinState(skinId)
        end

        if tonumber(flowerId) == tonumber(FlowerSkinType.kDefault) or dontQueryFlowerChange then
            finish(true)
            return
        end

        local skinName = vineSkinManager and vineSkinManager:getSkinName(skinId) or "藤蔓装扮"
        local flowerPrompt = string.format("%s有默认关卡花哦，是否更换？", skinName)
        local function onPanelClosed()
            self.flowerSkinPart:setMyFlowerId(FlowerSkin:getUserSkinType())
            finish(true)
        end

        local NewFlowerAlertVM = require "amf.feature.personalhub.personalcenter.view.newdressget.NewFlowerAlertVM"
        local panel = NewFlowerAlertVM:create({
            decoType = PersonalCenterConst.DecoPageSubTabType.kFlower,
            flowerId = FlowerSkinType.kDefault,
            closeCall = onPanelClosed,
        })
        local function updateFlowerPanelText()
            if panel.isDisposed or not panel.view then return end
            local panelView = panel.view
            local titleLabel = panelView.title
            if titleLabel then
                titleLabel:setString("关卡花用哪个？")
                titleLabel:setDimensions(CCSizeMake(360, 0))
                titleLabel:setOutlineWidth(3)
                local PanelNodeColorConfig = require "amf.middleware.ui.kit.commonpanel.utils.PanelNodeColorConfig"
                PanelNodeColorConfig:setPanelColorMode(CommonPaneColorType.Green, {
                    secondTitle = titleLabel,
                })
            end
            local promptLabel = panelView.NewFlowerAlertPanel_label_level_1
            if not promptLabel then return end
            promptLabel:setDimensions(CCSizeMake(520, 0))
            promptLabel:setString(flowerPrompt)

            local changeBtn = panelView.btnChangeNow
            if not changeBtn or panelView.vineSkinNoChangeBtn then return end

            local centerX = changeBtn:getPositionX()
            local buttonY = changeBtn:getPositionY()
            local buttonParent = changeBtn:getParent()
            changeBtn:removeFromParentAndCleanup(true)

            local UIButton = require "amf.middleware.ui.kit.component.button.UIButton"
            local newChangeBtn = UIButton:createButton({
                str = "立即更换",
                scaleMode = UIButtonConfig.BtnScales.k75,
                colorMode = UIButtonConfig.ColorMode.green,
                touchFunc = function()
                    if panel.isDisposed then return end
                    panel:onBtnChangeNow()
                end,
            })
            local noChangeBtn = UIButton:createButton({
                str = "不换了",
                scaleMode = UIButtonConfig.BtnScales.k75,
                colorMode = UIButtonConfig.ColorMode.green,
                touchFunc = function()
                    if panel.isDisposed then return end
                    panel:onCloseBtnTapped()
                end,
            })

            newChangeBtn:setPositionXY(centerX - 135, buttonY)
            noChangeBtn:setPositionXY(centerX + 135, buttonY)
            buttonParent:addChild(newChangeBtn)
            buttonParent:addChild(noChangeBtn)
            panelView.btnChangeNow = newChangeBtn
            panelView.vineSkinNoChangeBtn = noChangeBtn
        end
        panel:setPanelReadyCallback(updateFlowerPanelText)
        panel:setLoadResFailCallback(onPanelClosed)
        panel:popout()
        updateFlowerPanelText()
    end

    if vineSkinManager then
        vineSkinManager:setUsingSkinType(skinId, true):next(afterSkinChanged, function(err)
            CommonTip:showTip("资源加载失败，请检查网络或稍后重试~", "negative")
            finish(false, err)
        end)
    else
        afterSkinChanged()
    end
end

function PersonalCenterManager:_getNamePatterExpire(profile, namePatternId)
    if not namePatternId or tonumber(namePatternId) == 0 then
        return 0
    end

    local namePatternList = profile.namePatternList
    if not namePatternList then
        return 0
    end

    for _, v in pairs(namePatternList) do
        if tonumber(v.itemId) == tonumber(namePatternId) then
            return tonumber(v.expireTime) or 0
        end
    end

    return 0
end

------------------------ 弹面板 -------------------------------

function PersonalCenterManager:showThumbsInfoPanel()
    local promise = deferred.new()

    local function doPop()
        self:requestGetThumbsPanelInfo():next(function(data)
            local LikeHistoryPanelVM = require 'amf.feature.personalhub.personalcenter.view.LikeHistoryPanelVM'
            local panelVm = LikeHistoryPanelVM:create({
                closeCallback = function() promise:resolve() end,
                serverData = data,
                thumbLimit = PersonalCenterConst.THUMB_LIMIT_ONCE,
            })

            panelVm:setLoadResFailCallback(function()
                promise:reject()
            end)

            panelVm:popout()
        end, function()
            promise:reject()
        end)
    end

    if EnvUtil:isUnityEditor() then
        doPop()
    else
        WXLabel:loadFont(doPop)
    end

    return promise
end

function PersonalCenterManager:showOneTimePassStatsPanel(delegate)
    if not delegate then delegate = {} end
    local promise = deferred.new()
    if not delegate.data then
        local data = self:getNamecardInfo():getOneTimePassLevelData()
        delegate.data = data
    end

    local function doPop()
        promise:resolve()
        local PanelVM = require 'amf.feature.personalhub.personalcenter.view.OneTimePassStatsPanelVM'
        local panelVm = PanelVM:create({
            closeCallback = function() promise:resolve() end,
            data = delegate.data -- namecardInfo.oneTimePassLevelData
        })

        panelVm:setLoadResFailCallback(function()
            promise:reject()
        end)

        panelVm:popout()
    end

    if EnvUtil:isUnityEditor() then
        doPop()
    else
        WXLabel:loadFont(doPop)
    end

    return promise
end

function PersonalCenterManager:showWinStreakStatsPanel(delegate)
    if not delegate then delegate = {} end
    local promise = deferred.new()
    
    local PanelVM = require 'amf.feature.personalhub.personalcenter.view.WinningStreakShowPanelVM'
    local panelvm = PanelVM:create({
        closeCallback = function() promise:resolve() end,
    })
    panelvm:popout()

    promise:resolve()

    return promise
end

function PersonalCenterManager:openOthersKeepFullLevelPanel(callback)
    self:requestGetNameCardChildInfo(PersonalCenterConst.ChildInfoIndex.KEEP_FULL_LEVEL):next(function(data)
        local info = data.continueFullMainInfo
        local profile = self:getProfile()
        info.profile = profile

        _G.amfBean("KeepFullLevelManager"):showMainPanelForPersonalCenter(info, callback)
    end, callback)
end

function PersonalCenterManager:openEditNicknamePanel(title, from)
    local promise = deferred.new()

    local EditNicknamePanelVM = require "amf.feature.personalhub.personalcenter.view.EditNicknamePanelVM"
    local vm = EditNicknamePanelVM.Builder.new()
        :setColorType(PanelColorConst.ColorType.kPersonalCenter)
        :setIgnoreHasEntry(true)
        :setCloseCallback(function()
            promise:resolve()
        end)
        :setEditTitle(title)
        :setFrom(from)
        :setLoadResFailCallback(function()
            promise:reject()
        end)
        :build()
    vm:popout()

    self._updateProfileManager:requestProfileShowedChangeNickNamePanel()
    self:notify(PersonalCenterEvent.POP_USER_HEAD_GUIDE_TIP)

    return promise
end

function PersonalCenterManager:_openPersonalCenterPanel(delegate)
    local promise = deferred.new()

    local function doPop()
        local PersonalCenterPanelVM = require "amf.feature.personalhub.personalcenter.view.PersonalCenterPanelVM"
        local panelVm
        panelVm = PersonalCenterPanelVM.Builder.new()
            :setCloseCallback(function()
                self:removeObserver(panelVm)
                if delegate.closeCallback then
                    safeRunCall(delegate.closeCallback)
                end
                promise:resolve()
            end)
            :setPanelReadyCallback(function()
                self:dc("main_panel", {
                    version = 2022,
                    t1 = self:getMode(),
                    t2 = delegate.t2 or "other",
                    t3 = panelVm:getDcMainPanelT3(),
                    t4 = delegate.pageId == PersonalCenterConst.PageType.kRecord and 1 or 2,
                    panel_id = panelVm:getPanelId(),
                })
            end)
            :setLoadResFailCallback(function()
                self:removeObserver(panelVm)
                promise:reject()
            end)
            :setCardInfo(delegate.info)
            :setPageId(delegate.pageId)
            :setSubPageId(delegate.subPageId)
            :setSubPageItemId(delegate.subPageItemId)
            :setAuthorizedData(delegate.authorizedData)
            :build()

        self:addObserver(panelVm)
        panelVm:popout()
    end

    if EnvUtil:isUnityEditor() then
        doPop()
    else
        WXLabel:loadFont(doPop)
    end

    return promise
end

-- 尝试打开主面板
-- local delegate = {
--     id = 0,
--     isXxlId = false,
--     pageId = nil,
--     subPageId = nil,
--     subPageItemId = nil,
--     closeCallback = nil,
--     userClick = false,
--     authorizedData = nil,
-- }
function PersonalCenterManager:tryOpenPersonalCenterPanel(delegate)
    local promise = deferred.new()
    if not delegate or not delegate.id then
        delegate = delegate or {}
        delegate.id = self._profileManager:getUid()
        delegate.isXxlId = false
    end

    local id = delegate.id
    local isXxlId = delegate.isXxlId
    local isMe = self:isMeId(id, isXxlId)

    self._model:loadNamecardInfo(id, isMe, isXxlId):next(function(info)
        local currentScene = Director:sharedDirector():getRunningSceneLua()
        if not currentScene or not currentScene:isScene("MainScene") then
            promise:reject()
            return
        end

        delegate.info = info
        if delegate.userClick then
            self._model:setValue("userClick", true)
        end
        self:_openPersonalCenterPanel(delegate):next(function()
            self._model:popTopInfo()
            promise:resolve()
        end, function()
            self._model:popTopInfo()
            promise:reject()
        end)
    end, function()
        promise:reject()
    end)

    return promise
end

function PersonalCenterManager:tryOpenPromotionRankPanel(endCall)
    local promise = deferred.new()

    local profile = self:getProfile()
    if not profile or table.isEmpty(profile) then
        promise:reject()
        return promise
    end

    _G.amfBean("PromotionEventManager"):showHistoryPanel(5, profile):next(function()
        promise:resolve()
    end, function()
        promise:reject()
    end)

    return promise
end

function PersonalCenterManager:showConcealInfoPanel(delegate)
    if not delegate then delegate = {} end
    local promise = deferred.new()

    if self._profileManager then
        delegate.emptyProfile = self._profileManager:createEmptyProfile()
    end
    local PanelVM = require 'amf.feature.personalhub.personalcenter.view.ConcealInfoPanelVM'
    delegate.closeCallback = function() promise:resolve() end
    local panelVm = PanelVM:create(delegate)

    panelVm:setLoadResFailCallback(function()
        promise:reject()
    end)

    panelVm:popout()
    return promise
end

function PersonalCenterManager:showEditInfoPanel(delegate)
    if not delegate then delegate = {} end
    local promise = deferred.new()

    local function doPop()
        local PanelVM = require 'amf.feature.personalhub.personalcenter.view.EditInfoPanelVM'
        delegate.closeCallback = function() promise:resolve() end
        local panelVm = PanelVM:create(delegate)

        panelVm:setLoadResFailCallback(function()
            promise:reject()
        end)
        -- panelVm:initUI()

        panelVm:popout()
    end

    if EnvUtil:isUnityEditor() then
        doPop()
    else
        WXLabel:loadFont(doPop)
    end

    return promise
end

--显示切换地区警告面板
function PersonalCenterManager:showSwitchRegionConfirmPanel(delegate)
    local t2 = delegate.from
    local panel_id = UICreateUtil:getPanelId("SwitchRegionConfirmPanel")
    local province = nil
    if delegate and delegate.location then
        province = string.split(delegate.location, "#")[1] or ""
    end

    if delegate.province then
        province = delegate.province
    end

    local moduleText2 = nil
    if delegate.moduleText2 then
        moduleText2 = delegate.moduleText2
    else
        moduleText2 = "地区团战"
    end

    local excludeText = nil
    if delegate.excludeText then
        excludeText = delegate.excludeText
    end

    local addText = nil
    if delegate.addText then
        addText = delegate.addText
    end

    local panel
    local del

    local onCheckSuccess = function(isInCD, data)
        local moduleText = nil
        if delegate.moduleText then
            moduleText = delegate.moduleText
        else
            local t = {"地图团战", "荣誉排行"}
            if data and data.configList and data.specialUpdateLocationMap then
                t = {"荣誉排行"}
                for _, v in pairs(data.configList) do
                    local isOpen = data.specialUpdateLocationMap[tostring(v.id)]
                    if isOpen and tonumber(isOpen) > 0 then
                        table.insert(t, 1, v.desc)
                    end
                end
            end
            if addText then
                for _, v in pairs(addText) do
                    table.insert(t, v)
                end
            end
            if excludeText then
                for _, v in pairs(excludeText) do
                    table.removeIfExist(t, v)
                end
            end
            moduleText = table.concat(t, "、")
        end

        local syncLabel = (delegate.from == 1 and "个人名片") or (delegate.from == 3 and "荣耀排行") or "其他功能"
        local label = {
            desc = {
                "加入【"..province.."】，会同步修改"..syncLabel.."里的地区，",
                "<<c=ea6b34>且"..tostring(math.floor(self:getSelectRegionCDTimeByDay())).."天内不能再次修改。>",
                "您确定加入【"..province.."】吗？"
            },
        }
        -- if isInCD then
        --     label = {
        --         desc = {
        --             "您之前已修改过地区，在"..moduleText2,
        --             "<<c=ea6b34>只能修改1次。>",
        --             moduleText.."的地区也会同步修改。\n",
        --             "您确定要加入【"..province.."】吗？"
        --         },
        --     }
        -- else
        --     label = {
        --         desc = {
        --             "加入【"..province.."】后，会同步修改"..moduleText.."里的地区，",
        --             "<<c=ea6b34>且"..tostring(self:getSelectRegionCDTimeByDay()).."天内不能再次修改。>",
        --             "您确定加入【"..province.."】吗？"
        --         },
        --     }
        -- end
        local panel
        del = {
            text = label,
            -- todo面板颜色
            panelColorType = PanelColorConst.ColorType.kPersonalCenter,
            btnsConfig = {
                {
                    str = "取消",
                    widthMode = UIButtonConfig.Widths.kShort,
                    colorMode = UIButtonConfig.ColorMode.orange,
                    touchFunc = function ( btn )

                        if panel.isDisposed then return end
                        printx(42, "点击取消")
                        if not isInCD then
                            DcUtil:UserTrack({
                                category = "social_area",
                                sub_category = "area_affirm",
                                t1 = 2,
                                t2 = t2,
                            })
                        end
                        panel:close()
                        safeRunCall(delegate.closeCall, false)
                    end
                },
                {
                    str = "确定",
                    widthMode = UIButtonConfig.Widths.kShort,
                    colorMode = UIButtonConfig.ColorMode.green,
                    touchFunc = function ( btn )
                        printx(42, "点击确定")
                        if panel.isDisposed then return end
                        if not isInCD then
                            DcUtil:UserTrack({
                                panel_id = panel_id,
                                category = "social_area",
                                sub_category = "area_affirm",
                                t1 = 1,
                                t2 = t2,
                            })
                        end
                        panel:close()
                        safeRunCall(delegate.closeCall, true)
                    end
                },
            }
        }
        -- panel = FourthPanelA:create(del)
        local FourthPanelAVM = require "amf.middleware.ui.kit.panel.fourth.FourthPanelAVM"
        panel = FourthPanelAVM.Builder.new()
            :setText(del.text)
            :setButtonsConfig(del.btnsConfig)
            :setColorType(del.panelColorType)
            :build()

        panel:popout()
    end

    local onCheckFail = function()
        self:showProhibitConfirmPanel(delegate)
    end

    if not self:isInSelectRegionCD() then  --不在冷却期直接给过
        self:locationRankInfoCheckUpdate(delegate.funcId,function(inCD, data)
            safeRunCall(onCheckSuccess, false, data)
        end ,function(isCheckFail, data)
            if isCheckFail then --检测失败在弹出提示
                safeRunCall(onCheckSuccess, false, data)
            end
        end,nil)
    elseif delegate.funcId then --在冷却期间看看有没有额外机会
        self:locationRankInfoCheckUpdate(delegate.funcId,function()
            safeRunCall(onCheckSuccess,true)
        end ,function(isCheckFail, data)
            if isCheckFail then --检测失败在弹出提示
                self:showProhibitConfirmPanel(delegate)
            end
        end,nil)
    else
        self:showProhibitConfirmPanel(delegate)
    end

end

function PersonalCenterManager:locationRankInfoCheckUpdate(funcId,successCallback, failCallback, cancelCallback)
    local function onSuccess(evt)
        local data = evt or {}
        if tonumber(data.locationUpdateTime) > 0 then
            self._profileManager:setProfileValue("locationId", data.locationId)
            self._profileManager:setProfileValue("location", data.location)
            self._profileManager:setProfileValue("adcode", data.adcode)
            self._profileManager:setProfileValue("locationUpdateTime", data.locationUpdateTime)
        end

        local specialUpdateLocationMap  = data.specialUpdateLocationMap
        local configList = data.configList
        if funcId then
            local serverUseVersion = 0
            local serverNowVersion = 0
            if specialUpdateLocationMap[tostring(funcId)] then
                serverUseVersion =  specialUpdateLocationMap[tostring(funcId)]
            end
            for k,v in pairs(configList) do
                if v.id == funcId then
                    serverNowVersion = v.funcVersion
                end
            end
            if serverNowVersion > serverUseVersion then
                safeRunCall(successCallback, nil, data)
            else
                safeRunCall(failCallback, true, data)
            end
        else
            safeRunCall(successCallback, nil, data)
        end
    end

    local function onFail(evt)
        safeRunCall(failCallback)
    end

    local function onCancel()
        safeRunCall(cancelCallback)
    end
    local noLoading = false

    local promise = self:requestLocationRankInfoCheckUpdate()
    promise:next(onSuccess, onFail)

    -- safeRunCall(onSuccess, {data = {locationUpdateTime = 0}})
    -- self:requestServer('locationRankInfoCheckUpdate', {
    -- }, onSuccess, onFail, onCancel, noLoading)
end

function PersonalCenterManager:showProhibitConfirmPanel(delegate)
    if not self:isInSelectRegionCD() then
        safeRunCall(delegate.closeCall, true)
        return
    end

    local panel
    local del
    local location =  self:getLocation()
    if not location or location == "" then
        location = self._profileManager:getProfileValue("location") or ""
    end
    local lastProvince = string.split(location, "#")[1] or ""
    if lastProvince and lastProvince ~= "" and PersonalCenterConst.LOCATION_LEGAL_NAME[lastProvince] then
        lastProvince = PersonalCenterConst.LOCATION_LEGAL_NAME[lastProvince]
    end

    -- DcUtil:UserTrack({
    --     category = "social_area",
    --     sub_category = "change_fail",
    -- })

    local createLabelFunc = function()
        local cdDay = self:getSelectRegionCDTimeByDay()
        local lastChangeRegionTime = self:getLastChangeRegionTime() or 0
        local startDay = math.ceil(lastChangeRegionTime/1000/24/3600)
        local curDay = math.ceil(TimeKit:time()/1000/24/3600)

        local ts = math.floor(tonumber(lastChangeRegionTime) / 1000)
        local month =  tonumber( os.date( "%m" , ts ) )
        local day =  tonumber( os.date( "%d" , ts ) )
        local curRemainTime = startDay + cdDay - curDay
        local curRemainTime2 = math.floor(lastChangeRegionTime/1000 + cdDay*24*3600 - TimeKit:time()/1000)
        local label = nil
        if curRemainTime2/3600 > 24 then
            label = {
                desc = {
                    "您在"..tostring(month).."月"..tostring(day).."日加入了"..lastProvince.."地区，在\n",
                    "<<c=ea6b34>"..tostring(math.floor(cdDay)).."天内均不能再次修改地区\n>",
                    "请您在"..tostring(math.floor(curRemainTime)).."天后再更换地区哦~"
                },
            }
        else
            label = {
                desc = {
                    "您在"..tostring(month).."月"..tostring(day).."日加入了"..lastProvince.."地区，在\n",
                    "<<c=ea6b34>"..tostring(math.floor(cdDay)).."天内均不能再次修改地区\n>",
                    "请您在"..tostring( convertSecondToHHMMSSFormat(curRemainTime2)).."后再更换地区哦~"
                },
            }
        end
        return label, curRemainTime2
    end

    local label, curRemainTime2 = createLabelFunc()
    if curRemainTime2 <= 0 then
        printx(42, "时间到了687")
        return
    end
    del = {

        panelColorType = PanelColorConst.ColorType.kPersonalCenter,
        btnsConfig = {
            {
                str = "好的",
                widthMode = UIButtonConfig.Widths.kShort,
                colorMode = UIButtonConfig.ColorMode.green,
                touchFunc = function ( btn )
                    if panel.isDisposed then return end
                    panel:close()
                    safeRunCall(delegate.closeCall, false)
                end
            },
        }
    }

    local panelScheduleId
    -- 加tick
    panelScheduleId = CCDirector:sharedDirector():getScheduler():scheduleScriptFunc(function ()
        if not panel or panel.isDisposed then
            CCDirector:sharedDirector():getScheduler():unscheduleScriptEntry(panelScheduleId)
            return
        end

        local label, curRemainTime2 = createLabelFunc()

        if curRemainTime2 <= 0 then
            if panel and not panel.isDisposed then
                printx(42, "时间结束关闭1")
                panel:_close()
                safeRunCall(delegate.closeCall, false)
            end
            return
        end
        panel:update({text = label, textHAlign = kCCTextAlignmentCenter})
    end, 1, false)



    local FourthPanelAVM = require "amf.middleware.ui.kit.panel.fourth.FourthPanelAVM"
    panel = FourthPanelAVM.Builder.new()
        :setButtonsConfig(del.btnsConfig)
        :setText(label, kCCTextAlignmentCenter)
        :setColorType(del.panelColorType)
        :build()

    panel:popout()
end

------------------------ 主要外部接口 -------------------------------

function PersonalCenterManager:getLocationId(province)
    for _ ,v in pairs(PersonalCenterConst.RegionTable) do
        local locationId = v[1]
        local fullName =  v[2]
        if string.find(fullName, province) or string.find(province, fullName) then
            return locationId
        end
    end
    return
end

function PersonalCenterManager:setPlayerStatusClickedTs(ts)
    self._model:setValue("playerStatusClickedTs", ts)
end

function PersonalCenterManager:getPlayerStatusClickedTs()
    return self._model:getValue("playerStatusClickedTs") or 0
end

function PersonalCenterManager:updateLocationUpdateTime()
    self._userManager.locationUpdateTime = TimeKit:time()
    self._profileManager:setProfileValue("locationUpdateTime", TimeKit:time())
end

function PersonalCenterManager:validateName(val)
    val = self:formatStrDropLineBreak(val, true) or ""
    if val ~= "" then
        -- 敏感词过滤
        if IllegalWordFilterUtil.getInstance():isIllegalWord(val) then
            CommonTip:showTip(Localization:getInstance():getText("error.tip.illegal.word"), "negative")
            return false
        else
            return true
        end
    else
        CommonTip:showTip("昵称不能为空！", "negative")
        return false
    end
end

function PersonalCenterManager:validateSignature(val)
    val = self:formatStrDropLineBreak(val, true) or ""
    if val ~= "" then
        -- 敏感词过滤
        if IllegalWordFilterUtil.getInstance():isIllegalWord(val) then
            CommonTip:showTip(Localization:getInstance():getText("error.tip.illegal.word"), "negative")
            return false
        else
            return true
        end
    else
        CommonTip:showTip("签名不能为空！", "negative")
        return false
    end
end

function PersonalCenterManager:setMyName(val)
    self._userManager.profile:setDisplayName(val)
end

function PersonalCenterManager:setMySignature(val)
    self._userManager.profile:setDisplaySignature(val)
end

function PersonalCenterManager:setMyGender(val)
    self._userManager.profile.gender = val
end

function PersonalCenterManager:setMyBirthday(val)
    self._userManager.profile:setProfile(nil, nil, nil, val, nil)
end

function PersonalCenterManager:setMyLocation(val)
    self._userManager.profile:setProfile(nil, nil, nil, nil, val)
end


--上一次修改地区的时间
function PersonalCenterManager:getLastChangeRegionTime()
    return tonumber(self._profileManager:getLocationUpdateTime())
end

--是否在选择地区的cd中
function PersonalCenterManager:isInSelectRegionCD()
    local curTime = TimeKit:time()
    local lastChangedTime = self:getLastChangeRegionTime()
    if lastChangedTime == 0 or lastChangedTime == nil then
        return false
    end
    if curTime > lastChangedTime and
            (curTime - lastChangedTime)/1000/3600/24 < self:getSelectRegionCDTimeByDay() then
        return true
    end
   return false
end

--文字形式
function PersonalCenterManager:getSelectRegionCDTimeByDay()
   local cdDay = 180
   if self._userManager.locationCdTime and
           tonumber(self._userManager.locationCdTime) ~= 0 then
       cdDay = tonumber(self._userManager.locationCdTime)
   end
   local cd = 1000*60*60*24*cdDay
   local timeDay = cd/(1000*60*60*24)
   return timeDay
end

function PersonalCenterManager:getMainConfig()
    local config = self._model:getValue("serverVersionedConfig")
    return config.config or {}
end

-- 首闯徽章开始记录时间
function PersonalCenterManager:getOneTimePassTotalStatsStartTime()
    return self:getMainConfig().oneTimePassBadgeStartRecordTime or 0
end

-- 首过关率开始记录时间
function PersonalCenterManager:getOneTimePassRateStatsStartTime()
    return self:getMainConfig().oneTimePassBadgeMaxDayRecordTime or 0
end

-- 单日最高徽章开始记录时间
function PersonalCenterManager:getOneTimePassDailyMaxStatsStartTime()
    return self:getMainConfig().oneTimePassBadgeMaxDayRecordTime or 0
end

-- 连胜数据开始记录时间
function PersonalCenterManager:getWinStreakStatsStartTime()
    return self:getMainConfig().oneTimePassBadgeMaxDayRecordTime or 0
end

function PersonalCenterManager:getMode()
    local mode

    local profile = self:getProfile()
    local uid = self:getProfile().uid
    if uid == self._profileManager:getUid() then
        mode = PersonalCenterConst.PanelType.kMe
    else
        local friendInfo = self._friendManager:getFriendInfo(uid)
        if friendInfo then
            mode = PersonalCenterConst.PanelType.kFriend
        else
            mode = PersonalCenterConst.PanelType.kStrange
        end
    end

    return mode
end

function PersonalCenterManager:getNamecardInfo()
    return self._model:peekTopInfo()
end

function PersonalCenterManager:getProfile()
    local nameCardInfo = self:getNamecardInfo()
    if not nameCardInfo or not nameCardInfo.getProfile then return {} end
    return nameCardInfo:getProfile() or {}
end

function PersonalCenterManager:getUserDeco()
    local nameCardInfo = self:getNamecardInfo()
    if not nameCardInfo or not nameCardInfo.getUserDeco then return {} end
    return nameCardInfo:getUserDeco() or {}
end

function PersonalCenterManager:isBigVineDecoOpen()
    local namecardInfo = self:getNamecardInfo()
    return namecardInfo and namecardInfo:getBigVineDecoOpen() == true
end

function PersonalCenterManager:getSecreteV2()
    return self:getProfile().secretV2 or {}
end

function PersonalCenterManager:isAllowAddFriend()
    return self:getSecreteV2().noAllowAddFriend ~= true
end

function PersonalCenterManager:setAllowAddFriend(val)
    self:getSecreteV2().noAllowAddFriend = (val ~= true)
end

function PersonalCenterManager:isLocationSecret()
    return self:getSecreteV2().secretArea == true
end

function PersonalCenterManager:setLocationSecret(val)
    self:getSecreteV2().secretArea = val
end

function PersonalCenterManager:isBirthdaySecret()
    return self:getSecreteV2().secretBirthday == true
end

function PersonalCenterManager:setBirthdaySecret(val)
    self:getSecreteV2().secretBirthday = val
end

function PersonalCenterManager:isGenderSecret()
    return self:getSecreteV2().secretSex == true
end

function PersonalCenterManager:setGenderSecret(val)
    self:getSecreteV2().secretSex = val
end

function PersonalCenterManager:getGender()
    return self:getProfile().gender or 0
end

function PersonalCenterManager:getBirthday()
    return self:getProfile().birthDate or ""
end

function PersonalCenterManager:getLocation()
    return self:getProfile().location or ""
end

function PersonalCenterManager:getThumbsUpInfo()
    local cardInfo = self:getNamecardInfo()
    if cardInfo == nil then return {} end
    return cardInfo:getThumbsInfo() or {}
end

function PersonalCenterManager:canThumbsUp(info)
    local info = info or self._model:peekTopInfo()
    if info and info.getProfile then
        local isMe = self:isMe(info)
        if isMe then return false end

        local thumbsUpInfo = info:getThumbsUpInfo() or {}
        self._friendManager:checkFriendInfo(info:getProfile().uid)
        return thumbsUpInfo.canThumbsUp
    end

    return false
end

function PersonalCenterManager:hasOpenedPersonalCenterPanel()
    local count = self:getDataCount() or 0
    return count > 0
end

function PersonalCenterManager:generateRandomName()
    if not self.nickNameGenerator then
        local NicknameGenerator = require 'amf.feature.personalhub.personalcenter.config.NicknameGenerator'
        self.nickNameGenerator = NicknameGenerator.new()
    end

    local rdmName = self.nickNameGenerator:generate()
    -- printx(25, "rdmName "..tostring(rdmName))
    return rdmName
end

function PersonalCenterManager:getName(includeReviewInfo)
    if includeReviewInfo then
        local reviewName, reviewState = self:_getReviewName()
        if reviewName then
            return reviewName, reviewState
        end
    end

    return self:getProfile().name or ""
end

function PersonalCenterManager:getDisplayName(name)
    name = name or self:getName(true)
    local strName = nameDecode(name)
    strName = self:formatStrDropLineBreak(strName, true)
    strName = self:formatStrByChCount(strName, PersonalCenterConst.InputMaxLength.kName)
    if strName == "" then
        strName = "消消乐玩家"
    end
    return strName
end

function PersonalCenterManager:getDiaryCardBean()
    local namecardInfo = self:getNamecardInfo() or {}
    local topLevel = namecardInfo:getAreaInfo().topLevel
    if topLevel <= 140 then return nil end
    return namecardInfo:getDiaryCardBean()
end

function PersonalCenterManager:getSignature(includeReviewInfo)
    if includeReviewInfo then
        local reviewSignature, reviewState = self:_getReviewSignature()
        if reviewSignature then
            return reviewSignature, reviewState
        end
    end

    return self:getProfile().signature or ""
end

function PersonalCenterManager:getDisplaySignature(signature)
    signature = signature or self:getSignature(true)
    local strSignature = nameDecode(signature)
    strSignature = self:formatStrDropLineBreak(strSignature, true)
    strSignature = self:formatStrByChCount(strSignature, PersonalCenterConst.InputMaxLength.kSignature)
    if strSignature == "" then
        strSignature = "什么也没说"
    end
    return strSignature
end

function PersonalCenterManager:getConstellationByDate(strDate)
    local fakeProfile = {birthDate = strDate}
    self._profileManager:checkProfileAgeConstellation(fakeProfile)
    return fakeProfile.constellation
end

function PersonalCenterManager:getDisplayBirthday(handleSecret, birthday)
    local strBirthday = ""
    if handleSecret and self:isBirthdaySecret() then
        return strBirthday
    end

    birthday = birthday or nameDecode(self:getBirthday())
    if birthday ~= "" and string.len(birthday) == 8 then
        local year = string.sub(birthday, 1, 4)
        local month = string.sub(birthday, 5, 6)
        local day = string.sub(birthday, 7, 8)

        strBirthday = month.."月"..day.."日"
    end
    return strBirthday
end

function PersonalCenterManager:getConstellation()
    return self:getProfile().constellation or 0
end

function PersonalCenterManager:getDisplayConstellation(handleSecret, constellation)
    local strConstellation = ""
    if handleSecret and self:isBirthdaySecret() then
        return strConstellation
    end

    constellation = constellation or self:getConstellation()
    if constellation ~= "" and constellation > 0 then
        strConstellation = localize('my.card.edit.panel.content.constellation'..constellation)
    end
    return strConstellation
end

function PersonalCenterManager:getDisplayLocation(handleSecret, location, cutNum)
    local strSeg1 = "消消乐"
    local strSeg2 = "开心村"

    if handleSecret and self:isLocationSecret() then
        return strSeg1, strSeg2
    end

    location = location or self:getLocation()
    local strs = string.split(location, "#")
    if #strs >= 3 then
        if strs[1] == strs[2] then
            strSeg1 = strs[2]
            strSeg2 = strs[3]
        else
            strSeg1 = strs[1]
            strSeg2 = strs[2]
        end
    elseif #strs >= 2 then
        strSeg1 = strs[1]
        strSeg2 = strs[2]
    end

    if strSeg1 == strSeg2 then
        strSeg2 = ""
    end

    if PersonalCenterConst.LOCATION_LEGAL_NAME[strSeg1] then
        strSeg1 = PersonalCenterConst.LOCATION_LEGAL_NAME[strSeg1]
    end

    strSeg2 = StringKit:cutNameByteSensitive(strSeg2, cutNum or 10)

    return strSeg1, strSeg2
end

function PersonalCenterManager:getDisplayGender(handleSecret, gender)
    local strGender = ""
    if handleSecret and self:isGenderSecret() then
        return strGender
    end

    gender = gender or tonumber(self:getGender())
    if gender then
        strGender = PersonalCenterConst.STR_GENDER[gender + 1]
    end
    return strGender
end

function PersonalCenterManager:getHeadImageUrl(includeReviewInfo)
    if includeReviewInfo then
        local reviewHeadUrl, reviewState = self:_getReviewHeadImageUrl()
        if reviewHeadUrl then
            return reviewHeadUrl, reviewState
        end
    end

    local profile = self:getProfile()
    local headImageUrl = profile.headUrl
    if headImageUrl == nil then return tostring(HeadImageType.k_birth_0) end

    local headImageId = tonumber(headImageUrl)
    if not headImageId then return headImageUrl end
    if not table.exist(HeadImageType, headImageId) then return tostring(HeadImageType.k_birth_0) end
    return headImageUrl
end

-- 获取指定url对应的头像的审核状态，若不在审核区则返回nil
function PersonalCenterManager:getHeadImageReviewState(headImageUrl)
    local entry = self:_getHeadImageReviewEntry(headImageUrl)
    if not entry then return nil end

    return entry.state
end

function PersonalCenterManager:getAllCustomHeadImages(profile, withReviewImages)
    profile = profile or self:getProfile()
    local isMyProfile = profile.xxlId == self._profileManager:getXxlId()
    local data = {}

    local uniqueFileIds = {}
    local insertUniqueItem = function(fileId)
        if fileId == nil then return nil end
        if #fileId <= 0 then return nil end
        if uniqueFileIds[fileId] then return nil end

        uniqueFileIds[fileId] = true
        local item = {
            fileId = fileId,
            url = HeadImage:getCustomHeadImageUrlByFileId(fileId),
            submitTs = -#uniqueFileIds,
        }

        if isMyProfile then
            local entry = self:_getHeadImageReviewEntry(item.url)
            if entry then
                item.reviewState = entry.state
                item.submitTs = tonumber(entry.submitTs) or 0
            end
        end

        table.insert(data, item)
        return item
    end

    -- 审核区的自定义头像
    if withReviewImages and isMyProfile then
        local reviewingCustomHeadImageEntries = self._fenceManager:getCustomHeadImageEntries()
        for _, v in pairs(reviewingCustomHeadImageEntries) do
            local item = insertUniqueItem(v.content)
            if item then
                item.reviewState = v.state
                item.submitTs = tonumber(v.submitTs) or 0
            end
        end
    end

    -- profile中的自定义头像
    insertUniqueItem(profile.fileId)
    for _, v in pairs(profile.fileIds or {}) do
        insertUniqueItem(v)
    end

    table.sort(data, function(a, b)
        return a.submitTs > b.submitTs
    end)

    return data
end

function PersonalCenterManager:getAllSnsHeadImages(profile)
    profile = profile or self:getProfile()
    local isMyProfile = profile.xxlId == self._profileManager:getXxlId()
    local data = {}
    local snsMap = self._accountManager:getSnsMap()
    for _, v in pairs(snsMap or {}) do
        local isDebug = EnvUtil:isWindows() and v.snsPlatform == 'phone'
        if v.snsPlatform ~= 'alipay' or EnvUtil:isALIPAYMiniGame() then
            if isDebug or self._headImageSyncManager:canShowPlatformHeadImage(v.snsPlatform) then
                if string.starts(v.headUrl or '', 'http') then
                    local item = {
                        pf = v.snsPlatform,
                        pfName = PlatformConfig:getPlatformLocalizationBySnsName(v.snsPlatform),
                        url = v.headUrl,
                    }
                    if v.cdnHeadUrl and v.cdnHeadUrl~="" then
                        item.url = v.cdnHeadUrl
                        item.isCDNUrl = true
                        -- UWarning("!@#!##!@#!@#!@#!@#!@#!@#!@##!@#!@")
                    end

                    if isMyProfile then
                        local entry = self:_getHeadImageReviewEntry(item.url)
                        if entry then
                            item.reviewState = entry.state
                            item.submitTs = tonumber(entry.submitTs) or 0
                        end
                    end

                    table.insert(data, item)
                end
            end
        end
    end

    if isMyProfile then
        if EnvUtil:isWXMiniGame() then
            local targetItem = table.find(data, function(v)
                return v.pf == 'wechat'
            end)
            if not targetItem then
                local item = {
                    pf = 'wechat',
                    pfName = "微信",
                    snsMini = true,
                }
                table.insert(data, item)
            else
                targetItem.snsMini = true
            end
        elseif EnvUtil:isDYMiniGame() then
            local targetItem = table.find(data, function(v)
                return v.pf == 'tiktok'
            end)
            if not targetItem then
                local item = {
                    pf = 'tiktok',
                    pfName = "抖音",
                    snsMini = true,
                }
                table.insert(data, item)
            else
                targetItem.snsMini = true
            end
        elseif EnvUtil:isALIPAYMiniGame() then
            local targetItem = table.find(data, function(v)
                return v.pf == 'alipay'
            end)
            if not targetItem then
                local item = {
                    pf = 'alipay',
                    pfName = "支付宝",
                    snsMini = true,
                }
                table.insert(data, item)
            else
                targetItem.snsMini = true
                targetItem.localHeadUrl = "https://usr/head.png"
            end
        elseif EnvUtil:isHuaweiMiniGame() then
            local targetItem = table.find(data, function(v)
                return v.pf == 'huawei_mini'
            end)
            if not targetItem then
                local item = {
                    pf = 'huawei_mini',
                    pfName = "华为",
                    snsMini = true,
                }
                table.insert(data, item)
            else
                targetItem.snsMini = true
            end
        elseif EnvUtil:isUnionOppoMiniGame() then
            local targetItem = table.find(data, function(v)
                return v.pf == 'oppo'
            end)
            if not targetItem then
                local item = {
                    pf = 'oppo',
                    pfName = "OPPO",
                    snsMini = true,
                }
                table.insert(data, item)
            else
                targetItem.snsMini = true
            end
        elseif EnvUtil:isUnionMiMiniGame() then
            local targetItem = table.find(data, function(v)
                return v.pf == 'migame'
            end)
            if not targetItem then
                local item = {
                    pf = 'migame',
                    pfName = "MI",
                    snsMini = true,
                }
                table.insert(data, item)
            else
                targetItem.snsMini = true
            end
        elseif EnvUtil:isKuaiShouMiniGame() then
            local targetItem = table.find(data, function(v)
                return v.pf == 'ksmini'
            end)
            if not targetItem then
                local item = {
                    pf = 'ksmini',
                    pfName = "快手",
                    snsMini = true,
                }
                table.insert(data, item)
            else
                targetItem.snsMini = true
            end
        elseif EnvUtil:isJdMiniGame() then
            local targetItem = table.find(data, function(v)
                return v.pf == 'jd'
            end)
            if not targetItem then
                local item = {
                    pf = 'jd',
                    pfName = "京东",
                    snsMini = true,
                }
                table.insert(data, item)
            else
                targetItem.snsMini = true
            end
        end
    end

    return data
end

function PersonalCenterManager:setIsPopMiniHeadImageTip()
    -- 先存本地，每日的不存后端
    local day = TimeKit:getTodayStart()
    CCUserDefault:sharedUserDefault():setBoolForKey("PopMiniHeadImage"..day, true)
    CCUserDefault:sharedUserDefault():flush()
end

function PersonalCenterManager:getIsPopMiniHeadImageTip()
    local day = TimeKit:getTodayStart()
    return CCUserDefault:sharedUserDefault():getBoolForKey("PopMiniHeadImage"..day, false)
end

function PersonalCenterManager:setIsAutoExtendMiniHeadImage()
    self._serverCacheManager:setGuideFlag(GuideFlagConst.PersonalCardAutoExtendGuide)
end

function PersonalCenterManager:getIsAutoExtendMiniHeadImage()
    return self._serverCacheManager:hasGuideFlag(GuideFlagConst.PersonalCardAutoExtendGuide)
end

function PersonalCenterManager:getAllHeadImages(force)
    local profile = self:getProfile()
    local isMe = self:isMe()

    self._headImages = self._headImages or {}

    if not self._headImages[tostring(profile.xxlId)] or force then
        local dataList = {}
        if isMe then
            -- 只有自己的装扮才增加上传按钮及自定义头像、sns头像
            -- 上传按钮
            if not EnvUtil:isMiniGame() then
                table.insert(dataList, {upload = true})
            end

            -- 自定义头像
            local customHeadImageList = self:getAllCustomHeadImages(profile, true)
            -- UWarning("customHeadImageList: " .. tts(customHeadImageList))
            for _, v in pairs(customHeadImageList) do
                table.insert(dataList, {
                    custom = true,
                    pf = "animal",
                    fileId = v.fileId,
                    url = v.url,
                    isCDNUrl = true,
                    reviewState = v.reviewState
                })
            end

            -- SNS头像
            local snsHeadImageList = self:getAllSnsHeadImages(profile)
            -- UWarning("snsHeadImageList: " .. tts(snsHeadImageList))
            for _, v in pairs(snsHeadImageList) do
                table.insert(dataList, {
                    sns = true,
                    pf = v.pf,
                    pfName = v.pfName,
                    url = v.url,
                    isCDNUrl = v.isCDNUrl,
                    reviewState = v.reviewState,
                    snsMini = v.snsMini
                })
            end
        end

        local tmp = {}

        for _, id in pairs(_G.HeadImageType) do
            -- id <= 20 是出生头像，不是道具，无需 beginTime 检查
            if id <= 20 then
                local unlocked = self:isUnlockedHeadImage(profile, id)
                if isMe or unlocked then
                    table.insert(tmp, {
                        system = true,
                        id = id,
                        url = id,
                        unlock = unlocked
                    })
                end
            else
                local isDecoShowBegan, showBeginTime = self:isDecoShowBegan(id+20000)
                if not isDecoShowBegan then
                    self.newHeadImageShowBeginTime = self.newHeadImageShowBeginTime and math.min(self.newHeadImageShowBeginTime, showBeginTime) or showBeginTime
                else
                    local unlocked = self:isUnlockedHeadImage(profile, id)
                    if isMe or unlocked then
                        table.insert(tmp, {
                            system = true,
                            id = id,
                            url = id,
                            unlock = unlocked
                        })
                    end
                end
            end
        end

        table.sort(tmp, function ( a, b )
            if a.unlock == b.unlock then
                return a.id > b.id
            end
            return a.unlock
        end)

        dataList = table.union(dataList, tmp)

        self._headImages[tostring(profile.xxlId)] = dataList
    end

    return self._headImages[tostring(profile.xxlId)]
end

function PersonalCenterManager:isDecoShowBegan(propId)
    return _G.amfBean("PropManager"):isDecoVisible(propId)
end

function PersonalCenterManager:isCurrentHeadImage(headImageUrl)
    return self:compareHeadImageUrl(headImageUrl, self:getCurrentHeadUrlSource())
end

function PersonalCenterManager:getCurrentHeadUrlSource(profile)
    local selfHeadUrl = self._profileManager:getHeadUrl()
    local selfOriginHeadUrl = self._profileManager:getOriginHeadUrl()

    if tonumber(selfHeadUrl) then
        return selfHeadUrl
    end

    if selfOriginHeadUrl and selfOriginHeadUrl ~= "" then
        return selfOriginHeadUrl
    end

    return selfHeadUrl
end

function PersonalCenterManager:getHeadImageDesc(headImageId)
    if not headImageId then return "" end
    -- 直接走 localize，不经 PropManager
    -- 头像 propId(20000+)在 items_config 中与关卡花/名片卡 id 冲突，
    -- PropManager:getCategory 会把它们识别为 FLOWER 而非 HEADIMAGE

    local key = 'head.image.desc.'..headImageId
    str = localize(key) or ""
    if str == key then
        local propMgr = _G.amfBean("PropManager")
        str = propMgr:getPropDesc(propMgr:getPropIdByHeadImageId(headImageId))
    end
    return str
end

function PersonalCenterManager:getCustomHeadImageDesc()
    return localize('head.image.desc.custom') or ""
end

function PersonalCenterManager:getSnsHeadImageDesc(snsPlatform)
    return localize('head.image.desc.'..snsPlatform) or ""
end

function PersonalCenterManager:getHeadImageTotal()
    local total = 0

    for _, headImageId in pairs(HeadImage:getHeadImageList()) do
        -- getHeadImageList 已过滤 beginTime，直接计数
        total = total + 1
    end

    return total
end

function PersonalCenterManager:getCollectionStatString(unlockedItemCnt, itemCnt)
    local rankPercentage = self:getCollectionStatRank(unlockedItemCnt, itemCnt)
    rankPercentage = math.ceil(rankPercentage * 100)
    -- return string.format("收集度%d/%d      全国排名前%d%%", unlockedItemCnt, total, rankPercentage)

    local displayNum = math.floor(1 + (99 - 1) * (rankPercentage - 100) / (1 - 100))
    return string.format("收集度%d/%d      超过全国%d%%的玩家", unlockedItemCnt, itemCnt, displayNum)
end

function PersonalCenterManager:isUnlockedHeadImage(profile, headImageId)
	local profile = profile or self:getProfile()
	local headImageKey = table.keyOf(_G.HeadImageType, headImageId)
	if headImageKey then
		if string.starts(headImageKey, 'k_birth_') then
			return true
		end
		if string.starts(headImageKey, 'k_dynamic_') then
			return table.find(profile.dynamicHeadList or {}, function ( v )
				return v.id == headImageId
			end) ~= nil
		end
	end
	return false
end

function PersonalCenterManager:shareToWechat(xxlId)
    local xxlId = xxlId or self._profileManager:getXxlId()
    return self._friendManager:shareToWechat(xxlId)
end

function PersonalCenterManager:requestAddFriendUrl(inviteCode)
    local b = (not PlatformConfig:isPlatform(PlatformNameEnum.kMiTalk)) and
        (tonumber(inviteCode) ~= nil and #inviteCode >= 9 and #inviteCode <= 11)

    local uid = self._profileManager:getUid()
    local _, numOfFullStar = self._levelAreaManager:getAreaStarInfo()

    local url = AMFNetworkConfig:getDynamicHost()..'name_card.jsp?'
                ..'&starV2Enabled=1'
                ..'&fullStarArea='..numOfFullStar
                ..'&invitecode='..inviteCode..
                "&aaf=10"..
                "&uid="..uid
                .."&pid=".._G._PLATFORM_NAME

    local promise = deferred.new()

    self._model:requestShortUrl(url):next(function(response)
        local data = response:getData() or {}
        local shortUrl = data.extra or ''
        promise:resolve(shortUrl)
    end, function(response)
        promise:resolve(url)
    end)

    return promise
end

function PersonalCenterManager:copyAddFriendMsgToClipboard(inviteCode, addFriendUrl)
    -- 复制消消乐号成功
    local text = ""
    if inviteCode then
        local preStr = localize("addfriend_copy_sms_pre")
        local tagStr = localize("addfriend_copy_sms_tag")
        text = preStr..inviteCode..tagStr
    end

    text = text..localize("addfriend_copy_sms_tag2")..addFriendUrl..localize("addfriend_copy_sms_tag3")

    -- 我的消消乐号复制到剪切板
    ClipBoardUtil.copyText(text)
end

function PersonalCenterManager:getUserNickname()
    local nameCardInfo = self:getNamecardInfo()
    if not nameCardInfo or not nameCardInfo.getUserNickname then return {} end
    return nameCardInfo:getUserNickname() or {}
end

--------------------------- fence sync 头像上传 授权 相关 ----------------------------

function PersonalCenterManager:onTickByMyPanel()
    local myXxlId = self._profileManager:getXxlId()
    local ts = TimeKit:timeInMillis()

    if self.newHeadImageShowBeginTime and ts >= self.newHeadImageShowBeginTime then
        self.newHeadImageShowBeginTime = nil
        self._headImages = {}
        self:notify(PersonalCenterEvent.NEW_HEAD_IMAGE_BEGIN_SHOW)
    end

    self.headFramePart:onTick(myXxlId, ts)
    self.flowerSkinPart:onTick(myXxlId, ts)
    self.nicknameDecoPart:onTick(myXxlId, ts)

    -- 只在开着个人名片面板时才定时刷新审核区信息
    self._fenceManager:trySyncReviewInfo()
end

-- 复刻的app的AccountBindingLogic:updateSnsUserProfile
function PersonalCenterManager:updateSnsUserProfile(authorizeType, snsInfoSnsName, snsInfoName, snsInfoHeadUrl, snsInfoLocalHeadUrl)
    local function getValidName(rawName)
        if rawName == nil then return nil end
        if IllegalWordFilterUtil.getInstance():isIllegalWord(rawName) then
            return '消消乐玩家'
        else
            return rawName
        end
    end

    local profile = self:getProfile()
    local snsInfo = self:getSnsInfo()
    local oldSnsUrl = snsInfo.headUrl

    -- 要更新的第三方信息平台，如qq，wechat
    local snsPlatform = PlatformConfig:getPlatformAuthName(authorizeType)

    -- 敏感词检测
    snsInfoSnsName = getValidName(snsInfoSnsName)
    snsInfoName = getValidName(snsInfoName)

    -- 名字等文本encode
    local encodedSnsInfoSnsName
    if snsInfoSnsName then
        encodedSnsInfoSnsName = HeDisplayUtil:urlEncode(snsInfoSnsName)
    end
    local encodedSnsInfoName
    if snsInfoName then
        encodedSnsInfoName = HeDisplayUtil:urlEncode(snsInfoName)
    end

    local snsPlatformEnum = PlatformConfig:getPlatformAuthByName(snsPlatform)

    local operations = {
        {
            key = "snsDetail",
            op = "update",
            params = table.serialize{
                platform = snsPlatform,
                headUrl = snsInfoHeadUrl,
                name = encodedSnsInfoName,
                snsName = encodedSnsInfoSnsName,
                snsPlatformEnum = snsPlatformEnum,
            }
        }
    }

    local useImmediately = not profile.customProfile
    if useImmediately then
        table.insert(operations, {
            key = "name",
            op = "update",
            params = encodedSnsInfoName
        })

        -- table.insert(operations, {
        --     key = "headUrl",
        --     op = "update",
        --     params = snsInfoHeadUrl
        -- })
    end

    local callBack = function()

        --if not useImmediately and self.suggestUseWxInfo and authorizeType == PlatformAuthEnum.kWechat then
        if not useImmediately and self.suggestUseWxInfo and EnvUtil:isMiniGame() then
            self:suggestUseWxInfo(function(isSuccess)
                self:notify(PersonalCenterEvent.POP_DECO_SP_ITEM, {
                    subPageId = PersonalCenterConst.DecoPageSubTabType.kHead,
                    itemKey = "wx",
                })
            end, authorizeType)
        end

        if snsInfoHeadUrl then
            --绑定账号时尝试同步一次三方头像
            local ignoreCheck = oldSnsUrl ~= snsInfoHeadUrl
            self:syncThirdHeadImage(snsPlatformEnum, snsInfoHeadUrl, snsInfoLocalHeadUrl, useImmediately, nil, ignoreCheck)
        end

        if self._fenceManager:isV2Enabled() then
            local secureId = self._fenceManager:getSecureId()
            -- Fence 2期逻辑，只是先修改snsMap信息，对于name和headUrl的修改首先要提交fence审核，审核通过后再由后端来完成profile中name和headUrl的修改
            if useImmediately then
                self._fenceManager:requestSubmitReviewEntries(nil, nil, nil, {
                    encodedName = encodedSnsInfoName,
                    secureId = secureId
                })
            end
        end
    end

    self._headImages = nil
    self:requestUpdateProfile(operations, false):next(callBack)
end

-- 审核数据刷新了
function PersonalCenterManager:onReviewInfoUpdated(evt)
    local extra = evt.data
    if not extra then return end
    -- if not extra.changes then return end
    if not extra.hasChange then
        -- logD("no change!!!!")
        return
    end

    local myXxlId = self._profileManager:getXxlId()
    local profileUpdated = false

    if self:isMe() then
        -- logD("onReviewInfoUpdated "..table.tostring(extra))
        local namePassed = extra.passed.name ~= nil
        local signaturePassed = extra.passed.signature ~= nil
        -- local headUrlPassed = extra.passed.headUrl ~= nil
        local customHeadImagePassed = table.size(extra.passed.fileIds) > 0

        local msg
        if namePassed and signaturePassed and customHeadImagePassed then
            msg = "昵称、签名和头像审核成功，头像需手动更换哦~"
        elseif namePassed and customHeadImagePassed then
            msg = "昵称和头像审核成功，头像需手动更换哦~"
        elseif signaturePassed and customHeadImagePassed then
            msg = "签名和头像审核成功，头像需手动更换哦~"
        elseif namePassed and signaturePassed then
            msg = "昵称和签名审核成功！"
        elseif namePassed then
            msg = "昵称审核成功！"
        elseif signaturePassed then
            msg = "签名审核成功！"
        elseif customHeadImagePassed then
            msg = "头像审核成功，需手动更换哦~"
        else
        end
        if msg then
            CommonTip:showTip(msg)
        end
    end

    -- 刷新审核数据时，profile数据也发生了变化（一般是因为有审核通过的数据应用到profile上）
    if extra.profile and myXxlId == extra.profile.xxlId then
        -- 只关心审核涉及到的字段，其他的不动
        self._profileManager:setProfileValue("name", extra.profile.name)
        -- self._profileManager:setProfileValue("signature", extra.profile.signature)
        local headUrlChanged = self._profileManager:getHeadUrl() ~= extra.profile.headUrl
        self._profileManager:setProfileValue("headUrl", extra.profile.headUrl)
        self._profileManager:setProfileValue("originHeadUrl", extra.profile.originHeadUrl)

        profileUpdated = true

        local cardInfos = self._model:getNameCardInfoStack()
        local info = table.find(cardInfos, function(info)
            return self:isMe(info)
        end)
        local infoProfile = info and info.getProfile and info:getProfile()

        if infoProfile then
            infoProfile.name = extra.profile.name
            infoProfile.signature = extra.profile.signature
            infoProfile.fileId = extra.profile.fileId
            infoProfile.fileIds = extra.profile.fileIds
            infoProfile.headUrl = extra.profile.headUrl
            infoProfile.originHeadUrl = extra.profile.originHeadUrl

            info:setProfile(infoProfile)
        end

        if headUrlChanged then
            self:notifyHeadImageObserver()
        end
    end

    -- 将缓存的头像列表清空以进行刷新
    self._headImages = nil
    -- UWarning("PersonalCenterEvent.REVIEW_INFO_UPDATED")
    self:notify(PersonalCenterEvent.REVIEW_INFO_UPDATED, extra)
    if profileUpdated then
        MainSceneEventCenter:dispatch(MainSceneEvent.View.UPDATE_USER_NAME)
        self:notify(PersonalCenterEvent.PROFILE_UPDATED, myXxlId)
    end
end

function PersonalCenterManager:notifyHeadImageObserver()
    HeadImageObserver:notify()
end

function PersonalCenterManager:_getReviewHeadImageUrl()
    if not self:isMe() then return end

    local reviewHeadUrl, reviewState
    if self._fenceManager:hasHeadUrlEntry() then
        reviewHeadUrl = self._fenceManager:getHeadUrl()
        reviewState = self._fenceManager:getHeadUrlState()
    end
    return reviewHeadUrl, reviewState
end

function PersonalCenterManager:_getHeadImageReviewEntry(headImageUrl)
    if not self:isMe() then return nil end

    --获取当前使用的头像审核记录时，将其映射回到原始链接
    local selfHeadUrl = self._profileManager:getHeadUrl()
    local selfOriginHeadUrl = self._profileManager:getOriginHeadUrl()

    if selfHeadUrl == headImageUrl then
        if selfOriginHeadUrl and selfOriginHeadUrl ~= "" then
            headImageUrl = selfOriginHeadUrl
        end
    end

    return self._fenceManager:getEntryHistoryByUrl(headImageUrl)
end

function PersonalCenterManager:_getReviewName()
    if not self:isMe() then return end

    local reviewName, reviewState
    if self._fenceManager:hasNameEntry() then
        reviewName = self._fenceManager:getName()
        reviewState = self._fenceManager:getNameState()
        -- review区昵称审核状态不应为已通过，该状态应该只存在于后端。如果出现在前端，根据情况决定是否按审核中处理
        if reviewState == FenceConst.ReviewState.PASSED then
            -- 若与profile的昵称一致，则直接展示原昵称，否则按照审核中展示
            if reviewName == self:getName() then
                reviewName, reviewState = nil, nil
            else
                reviewState = FenceConst.ReviewState.REVIEWING
            end
        end
    end
    return reviewName, reviewState
end

function PersonalCenterManager:_getReviewSignature()
    if not self:isMe() then return end

    local reviewSignature, reviewState
    if self._fenceManager:hasSignatureEntry() then
        reviewSignature = self._fenceManager:getSignature()
        reviewState = self._fenceManager:getSignatureState()
        -- review区签名审核状态不应为已通过，该状态应该只存在于后端。如果出现在前端，根据情况决定是否按审核中处理
        if reviewState == FenceConst.ReviewState.PASSED then
            -- 若与profile的签名一致，则直接展示原昵称，否则按照审核中展示
            if reviewSignature == self:getSignature() then
                reviewSignature, reviewState = nil, nil
            else
                reviewState = FenceConst.ReviewState.REVIEWING
            end
        end
    end
    return reviewSignature, reviewState
end

-- 删除穿戴指定头像的审核信息，若不指定url，则删除当前穿戴头像的审核信息
function PersonalCenterManager:deleteHeadUrlReviewInfo(successCallback, failCallback, cancelCallback, url)
    if not self._fenceManager:hasHeadUrlEntry() then
        safeRunCall(successCallback)
        return
    end

    local reviewHeadUrl = self._fenceManager:getHeadUrl()
    if url ~= nil and not self:compareHeadImageUrl(reviewHeadUrl, url) then
        safeRunCall(successCallback)
        return
    end

    url = reviewHeadUrl

    self._fenceManager:requestDeleteHeadUrl(function()
        self._headImages = nil
        self:notify(PersonalCenterEvent.REVIEW_INFO_UPDATED)
        safeRunCall(successCallback)
    end,
    failCallback,
    cancelCallback,
    url)
end

-- 注意 这个接口纯手动才调用，自动更换三方不调用
function PersonalCenterManager:requestReviewNameAndSignature(successCallback, failCallback, cancelCallback, name, signature)
    self._fenceManager:requestReviewNameAndSignature(successCallback,
    failCallback,
    cancelCallback,
    name,
    signature)
    self:requestUpdateProfile({}, true)
end

function PersonalCenterManager:requestReviewHeadImage(successCallback, failCallback, cancelCallback, headUrl, sourceType)
    self._fenceManager:requestReviewHeadUrl(function()
        self._headImages = nil
        self:notify(PersonalCenterEvent.CHANGE_HEAD_IMAGE, headUrl)
        safeRunCall(successCallback)
    end,
    failCallback, cancelCallback, headUrl, sourceType)
end

function PersonalCenterManager:canUploadCustomHeadImage()
    if EnvUtil:isWindows() then return true end
    if EnvUtil:isMiniGame() then return false end

    local _authorType = self._accountManager:getSnsAuthorType()
    return _authorType and _authorType ~= PlatformAuthEnum.kGuest
end

function PersonalCenterManager:takePhoto(successCallback, failCallback)
    if self._photoMode then return end

    self._photoMode = true
    local cb = {
        onSuccess = function(path)
            self._photoMode = false
            if path ~= nil then
                self:syncCustomHeadImage(path, successCallback, failCallback)
            else
                safeRunCall(failCallback)
            end
        end,
        onError = function(code, errMsg)
            self._photoMode = false
            CommonTip:showTip(localize("my.card.edit.panel.warning.camera"), nil, nil, 3)
            safeRunCall(failCallback)
        end,
        onCancel = function()
            self._photoMode = false
            safeRunCall(failCallback)
        end,
    }
    TakePhotoUtil:takePicture(cb)
end

function PersonalCenterManager:selectPicture(successCallback, failCallback)
    if self._photoMode then return end

    self._photoMode = true
    local cb = {
        onSuccess = function ( path )
            self._photoMode = false
            if path ~= nil then
                self:syncCustomHeadImage(path, successCallback, failCallback)
            end
        end,
        onError = function ( code, errMsg )
            self._photoMode = false
            CommonTip:showTip(localize("my.card.edit.panel.warning.photo"), nil, nil, 3)
            safeRunCall(failCallback)
        end,
        onCancel = function ()
            self._photoMode = false
            safeRunCall(failCallback)
        end,
    }
    TakePhotoUtil:selectPicture(cb)
end

function PersonalCenterManager:syncCustomHeadImage(path, onSuccess, onFail)
    self._headImageSyncManager:syncCustomHeadFromLocal(path, function(fileId, headUrl)
        local profile = self:getProfile()
        local fileIds = profile.fileIds or {}
        table.insertIfNotExist(fileIds, fileId)
        profile.fileIds = fileIds

        self._headImages = nil
        self:notify(PersonalCenterEvent.ADD_HEAD_IMAGE, headUrl)

        if onSuccess then onSuccess(fileId, headUrl) end
    end, onFail)
end

function PersonalCenterManager:syncThirdHeadImageManually(plantform, onSuccess, onFail)
    self._headImageSyncManager:syncThirdHeadImageManually(plantform, function(error, newUrl, newCdnUrl)
        if error == 0 then
            local profile = self:getProfile()
            for _, v in pairs(profile.snsMap or {}) do
                if v.snsPlatform == plantform then
                    v.headUrl = newUrl
                    v.cdnHeadUrl = newCdnUrl
                end
            end
            self._headImages = nil
            if profile and not table.isEmpty(profile) then
                self:notify(PersonalCenterEvent.PROFILE_UPDATED, self:getProfile().xxlId)
            end

            safeRunCall(onSuccess, newUrl, newCdnUrl)
        else
            safeRunCall(onFail, error, newUrl, newCdnUrl)
        end
    end)
end

function PersonalCenterManager:syncThirdHeadImage(platform, thirdUrl, localUrl, useImmediately, callback, ignoreCheck)
    self._headImageSyncManager:syncThirdHeadImage(platform, thirdUrl, nil, useImmediately, function(newCdnUrl, error)
        if error == nil then
            local cardInfos = self._model:getNameCardInfoStack()
            local info = table.find(cardInfos, function(info)
                return self:isMe(info)
            end)
            local profile = info and info.getProfile and info:getProfile()

            self._headImages = nil

            if profile then
                local list = {}

                for _, v in pairs(profile.snsMap or {}) do
                    if v.snsPlatform == PlatformConfig:getPlatformAuthName(platform) then
                        v.headUrl = thirdUrl
                        v.cdnHeadUrl = newCdnUrl

                        table.insert(list,{
                            key = "snsDetail",
                            op = "update",
                            params = table.serialize{
                                platform = PlatformConfig:getPlatformAuthName(platform),
                                cdnHeadUrl = newCdnUrl,
                                snsPlatformEnum = platform,
                            }
                        })
                    end
                end

                if #list > 0 then
                    self._headImages = nil
                    self:requestUpdateProfile(list, false)
                end
            end
        end

        safeRunCall(callback, newCdnUrl)
    end, true, ignoreCheck, localUrl)
end

function PersonalCenterManager:deleteCustomHeadImage(fileId, url, successCallback, failCallback)
    url = tostring(url)
    local namecardInfo = self:getNamecardInfo()
    local profile = namecardInfo:getProfile()
    local isCurrentProfileHeadUrl = self:isCurrentHeadImage(url)
    -- local fileId = table.find(table.union(profile.fileIds or {}, {profile.fileId}), function (v)
    --     return HeadImage:getCustomHeadImageUrlByFileId(v) == url
    -- end)

    if not fileId then
        safeRunCall(failCallback)
        return
    end

    local function updateProfileIfNeccessary()
        local fileIdDeleted = false
        profile.fileIds = table.filter(profile.fileIds or {}, function (v)
            if v == fileId then
                fileIdDeleted = true
                return false
            end
            return true
        end)

        if profile.fileId == fileId then
            fileIdDeleted = true
            profile.fileId = profile.fileIds[1] or ''
        end

        namecardInfo:setProfile(profile)

        if isCurrentProfileHeadUrl then
            self:setMyHeadImageUrl(1)
        end

        if fileIdDeleted then
            self:requestUpdateProfile({
                {
                    key = "fileId",
                    op = "del",
                    params = fileId,
                },
                {
                    key = "fileIds",
                    op = "update",
                    params = table.isEmpty(profile.fileIds) and "[]" or table.serialize(profile.fileIds)
                }
            }, true)

            self._headImages = nil
            self:notify(PersonalCenterEvent.DELETE_HEAD_IMAGE, url)
        end

        safeRunCall(successCallback)
    end

    local function onSuccess()
        -- headUrl可能有对应审核信息，fileId也可能有对应审核信息，要删的review信息不同
        local found = false
        local reviewingCustomHeadImageEntries = self._fenceManager:getCustomHeadImageEntries()
        for _, v in pairs(reviewingCustomHeadImageEntries) do
            if v.content == fileId then
                found = true
                break
            end
        end

        if found then
            self._fenceManager:requestDeleteFileId(function()
                self._headImages = nil
                self:notify(PersonalCenterEvent.DELETE_HEAD_IMAGE, url)
                updateProfileIfNeccessary()
            end, failCallback, failCallback, fileId)
        else
            self:deleteHeadUrlReviewInfo(updateProfileIfNeccessary, failCallback, failCallback, url)
        end
    end

    self._headImageSyncManager:deleteCustomHead(fileId, onSuccess, failCallback)
end

function PersonalCenterManager:deleteSnsHeadImage(url, snsPlatform, successCallback, failCallback)
    url = tostring(url)
    local profile = self:getProfile()
    local isCurrentProfileHeadUrl = self:isCurrentHeadImage(url)

    local snsPlatformEnum = PlatformConfig:getPlatformAuthByName(snsPlatform)

    local function updateProfileIfNeccessary()
        local snsHeadUrlDeleted = false
        local sns = table.find(profile.snsMap or {}, function (v)
            return v.snsPlatform == snsPlatform
        end)
        if sns then
            sns.headUrl = ''

            self:requestUpdateProfile({
                {
                    key = "snsDetail",
                    op = "delSnsHead",
                    params = table.serialize{
                        snsPlatform = snsPlatform,
                        snsPlatformEnum = snsPlatformEnum,
                    }
                }
            }, true)

            self._headImages = nil
            self:notify(PersonalCenterEvent.DELETE_HEAD_IMAGE, url)
        end

        if isCurrentProfileHeadUrl then
            local newHeadImageUrl = 1
            self:setMyHeadImageUrl(newHeadImageUrl)
        end

        safeRunCall(successCallback)
    end

    self:deleteHeadUrlReviewInfo(updateProfileIfNeccessary, failCallback, failCallback, url)
end

------------------------------------------------------------------------------------------------------------------------------

function PersonalCenterManager:requestSendEnergy(uid, onSuccess, onFail)
    uid = tonumber(uid) or self:getProfile().uid
    if not uid then
        safeRunCall(onFail, "uid is nil")
    end

    local needLoading = true
    self._friendManager:requestSendFreeGift({
        type = FriendConst.sendGiftSendType,
        messageId  = nil,
        receiverUids = {uid},
        itemId = FriendConst.sendGiftItemId,
        disableFirstAskReward = true,
    },needLoading):next(onSuccess,function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        onFail(response)
    end)
end

function PersonalCenterManager:requestDeleteFriend(uid)
    local promise = deferred.new()

    self._friendManager:requestDelete({friendUids = {uid}}, true):next(function(evt)
        CommonTip:showTip("删除好友成功！")
        promise:resolve()
    end,function(evt)
        CommonTip:showErrorTip(evt)
        promise:reject()
    end)

    return promise
end

function PersonalCenterManager:requestAddFriend(xxlId)
    local promise = deferred.new()

    if self._friendManager:isFriendCountReachedMax() then
        CommonTip:showTip("好友数量已达500人上限，添加好友失败~")
        return promise:reject()
    end

    self._friendManager:requestAddFriendAddition({inviteCode = xxlId}, true):next(function(evt)
        CommonTip:showTip('好友申请已发送,请耐心等待对方通过哦~')
        promise:resolve()
    end,function(evt)
        if evt:getErrorCode() == 730355 then
            CommonTip:showTip("不同平台不可以加好友哦~")
            promise:reject(true)
        else
            CommonTip:showErrorTip(evt)
            promise:reject()
        end
    end)

    return promise
end

function PersonalCenterManager:isUserInfoAuthorized()
    local cacheUserInfo = self._settingManager:getModelData("weChatUserInfo", true)
    return cacheUserInfo and cacheUserInfo.nickname and true or false
end

function PersonalCenterManager:getUserInfoAuthorized()
    local cacheUserInfo = self._settingManager:getModelData("weChatUserInfo", true)
    return {
        nickname = cacheUserInfo and cacheUserInfo.nickname or "",
        headUrl = cacheUserInfo and cacheUserInfo.headUrl or "",
    }
end

function PersonalCenterManager:isNeedPrivacyAuthorized()
    return self._needAuthor
end

function PersonalCenterManager:checkNeedPrivacyAuthorized()
    local promise = deferred.new()
    return promise:resolve(false)
end

function PersonalCenterManager:requirePrivacyAuthorize()
    local promise = deferred.new()
    return promise:resolve(true)
end

function PersonalCenterManager:getSnsInfo(platformEnum)
    platformEnum = platformEnum or PersonalCenterConst.CurrentPlatformEnum
    local snsInfo = self._accountManager:getSnsInfo(platformEnum)
    return snsInfo
end

function PersonalCenterManager:hasWxSnsInfo()
    local snsInfo = self:getSnsInfo()
    return snsInfo and snsInfo.headUrl and snsInfo.headUrl ~= ""
end
------------------------ 工具方法 ------------------------------
function PersonalCenterManager:dc(subCategory, others)
    local params = {
        category = "my_card_"..(others.version or 2024),
        sub_category = subCategory
    }
    if others then
        for k,v in pairs(others) do
            params[k] = v
        end
    end
    DcUtil:UserTrack(params)
end

function PersonalCenterManager:formatStrDropLineBreak(str, trimIfIsAllBlank)
    str = string.gsub(str, '[\n,\r]', '')
    if trimIfIsAllBlank and string.trimAllSpace(str) == "" then
        str = ""
    end
    return str
end

function PersonalCenterManager:formatStrByChCount(str, maxChCount)
    local ret = ""
    local len = 0
    local lengthExceed = false
    for uchar in string.gfind(str, "[%z\1-\127\194-\244][\128-\191]*") do
        if maxChCount >= 0 and len >= maxChCount then
            lengthExceed = true
            break
        end

        if uchar then
            ret = ret..uchar
            len = len + 1
        end
    end

    return ret, len, lengthExceed
end

function PersonalCenterManager:formatXxlId(xxlId)
    if not xxlId then return "" end

    local strXxlId = tostring(xxlId)
    local ret = ""
    local startPos = 0
    local strLen = string.len(strXxlId)
    while true do
        local endPos = math.min(strLen, startPos + 3)
        ret = ret..string.sub(strXxlId, startPos + 1, endPos)
        if endPos == strLen then
            break
        end
        ret = ret.." "
        startPos = endPos
    end
    return ret
end

function PersonalCenterManager:getUsingDeco(decoType)
    local usingDeco = self:getUserDeco().usingDeco or {}

    local decoId = usingDeco[tostring(decoType)]
    if decoId == nil then
        if decoType == PersonalCenterConst.UserDecoType.kFlower then
            decoId = _G.FlowerSkinType.kDefault
        elseif decoType == PersonalCenterConst.UserDecoType.kUserInfoBg then
            decoId = _G.UserInfoBgType.kDefault
        end
    end

    return decoId
end

function PersonalCenterManager:getNamecardBgId()
    local namecardBgId = self:getUsingDeco(UserDecoType.kUserInfoBg)
    if namecardBgId == nil then return _G.UserInfoBgType.kDefault end
    if not table.exist(_G.UserInfoBgType, namecardBgId) then return UserInfoBgType.kDefault end
    return namecardBgId
end

function PersonalCenterManager:setUsingDeco(decoType, val)
    local userDeco = table.clone( self:getUserDeco() )
    local usingDeco = userDeco.usingDeco or {}
    usingDeco[tostring(decoType)] = val

    local nameCardInfo = self:getNamecardInfo()
    if nameCardInfo then
        nameCardInfo:setUserDeco(userDeco)
    end
end

function PersonalCenterManager:setUsingHeadFrame(val)
    local nameCardInfo = self:getNamecardInfo()
    if nameCardInfo then
        nameCardInfo:setHeadFrame(val)
    end
end

function PersonalCenterManager:getAllNormalRecordInfo()
    local ret = {}
    for k,v in pairs(PersonalCenterConst.NormalRecord) do
        ret[v] = self:getNormalRecordInfo(v)
    end
    return ret
end

function PersonalCenterManager:compareHeadImageUrl(url1, url2)
    url1 = tostring(url1)
    url2 = tostring(url2)

    if url1 == url2 then
        return true
    end

    local isUrl1Http = string.starts(url1, 'http')
    local isUrl2Http = string.starts(url2, 'http')

    if isUrl1Http and isUrl2Http then

        url1 = getProtocolRelativeUrl(url1)
        url2 = getProtocolRelativeUrl(url2)

        return url1 == url2
    else
        return false
    end
end

function PersonalCenterManager:getCollectionStatRank(unlockedItemCnt, itemCnt)
    local range1 = 0.2
    local range2 = 0.5
    local range3 = 0.98
    local rank1 = 0.84
    local rank2 = 0.43
    local rank3 = 0.01
    local collectRate = unlockedItemCnt / itemCnt
    local rank
    if collectRate < range1 then
        local f = math.clamp(collectRate / range1, 0, 1)
        f = math.pow(f, 2)
        rank = 1 + (rank1 - 1) * f
    elseif collectRate < range2 then
        local f = math.clamp((collectRate - range1) / (range2 - range1), 0, 1)
        rank = rank1 + (rank2 - rank1) * f
    elseif collectRate < range3 then
        local f = math.clamp((collectRate - range2) / (range3 - range2), 0, 1)
        f = 1 - math.pow((1 - f), 1.5)
        rank = rank2 + (rank3 - rank2) * f
    else
        rank = rank3
    end

    rank = math.max(0.01, rank)

    return rank
end

------------------------ 事件 ---------------------------------

function PersonalCenterManager:onPlayerStatusUpdated(evt)
    local playerStatus = evt.data
    local namecardInfo = self:getNamecardInfo()

    if namecardInfo and namecardInfo.getProfile and self:isMe(namecardInfo) then
        local profile = namecardInfo:getProfile()
        profile.playerStatus = playerStatus
        namecardInfo:setProfile(profile)
        self:notify(PersonalCenterEvent.PLAYER_STATUS_UPDATED)
    end
end

function PersonalCenterManager:onFriendStatusViewed(evt)
    local xxlIdStatusMap = evt.data
    local namecardInfo = self:getNamecardInfo()

    if self:isMe(namecardInfo) then
        namecardInfo:setAndHandleFriendsStatusInfo(xxlIdStatusMap)
        self:notify(PersonalCenterEvent.FRIEND_STATUS_VIEWED)
    end
end

function PersonalCenterManager:onActTestButtonReady()
    addGlobalTestButton("头像替换", function()
        local VM = require "amf.feature.personalhub.personalcenter.view.newdressget.NewHeadImageAlertPanelVM"
        local delegate = {
            newHeadImageUrl = HeadImageType.k_dynamic_anniversary10th_time_machine,
            closeCall = function()
            end
        }
        local vm = VM:create(delegate)
        vm:popout()
        return nil, true
    end, {
        TestButtonConst.Tags.ACTIVITY,
    })
end

function PersonalCenterManager:onActEnterStage3(evt)
    self:updateIcon()

    if not self:checkStage3CanPop() then return end

    local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.PERSONAL_CARD_GUIDE)
	end

	local function creator()
        self:openEditNicknamePanel():next(onHandleOver, onHandleOver)
	end

	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.PERSONAL_CARD_GUIDE, creator)
end

function PersonalCenterManager:checkStage3CanPop()
    if EnvUtil:isMiniGame() then return false end
    if not self:isEnabled() then return false end
    if _G.getTopLevelId() >= 21 then return false end
    if self._profileManager:getIsCustomProfile() then return false end
    if self._profileManager:getShowedChangeNickNamePanel() then return false end
    if not self._networkStatusManager:isNetworkEnabled() then return false end

    return true
end

function PersonalCenterManager:onActEnterStage4(evt)
    self:updateIcon()

    if not self:checkStage4CanPop() then return end

    local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.PERSONAL_CARD_GUIDE)
	end

	local function creator()
        if EnvUtil:isMiniGame() then
		    self:showIconGuide():next(onHandleOver, onHandleOver)
        else
            self:openEditNicknamePanel():next(onHandleOver, onHandleOver)
        end
	end

	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.PERSONAL_CARD_GUIDE, creator)
end

function PersonalCenterManager:checkStage4CanPop()
    if not self:isEnabled() then return false end
    if _G.getTopLevelId() < 21 then return false end

    if EnvUtil:isMiniGame() then
        if self._serverCacheManager:hasGuideFlag(GuideFlagConst.PersonalCardIconGuide) then return false end
    else
        if self._profileManager:getShowedChangeNickNamePanel() then return false end
        if not self._networkStatusManager:isNetworkEnabled() then return false end
    end

    if self._profileManager:getIsCustomProfile() then return false end

    return true
end

function PersonalCenterManager:onIconPoolExpand(evt)
end

function PersonalCenterManager:onIconPoolHide(evt)
end

------------------------ icon ----------------------------------
function PersonalCenterManager:showIconGuide()
    local promise = deferred.new()

    local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"
    IconEventCenter:dispatch(IconEvent.OPEN_ICON_POOL, IconMeta.PoolType.kRightCorner)

    local icon = self._iconManager:getIconByIconKey(IconKey.kNameCard)
    if not icon then return promise:reject() end

    local HeGuide = require 'amf.middleware.ui.kit.component.HeGuide'
    local heGuide = HeGuide:create(nil, true, nil, nil, true)
    heGuide:addAccurateGuide(icon.icon, { icon })
    heGuide:setEndCall(function()
        if self.cancelAutoPopup then
            self.cancelAutoPopup()
        end
    end)
    local contentList = {
        {ttf = "您可在【我的名片】里查看游戏记录并修改头像、昵称和装扮哦~"},
    }
    heGuide:showNpc2(contentList, 80, nil, 0)
    self.iconHeGuide = heGuide

    self._serverCacheManager:setGuideFlag(GuideFlagConst.PersonalCardIconGuide)

    self.cancelAutoPopup = _G.convert2ThrowawayFunction(function()
        if self.iconHeGuide then
            self.iconHeGuide:removeGuide()
            self.iconHeGuide = nil
        end
        promise:resolve()
    end, 5)

    return promise
end

function PersonalCenterManager:updateIcon()
    local icon = self._iconManager:getIconByIconKey(IconKey.kNameCard)
    if icon then
        icon:updateState()
    end
end

function PersonalCenterManager:onIconTouch()
    self:tryOpenPersonalCenterPanel({
        userClick = true,
        pageId = PersonalCenterConst.PageType.kRecord,
        -- subPageId = PersonalCenterConst.DecoPageSubTabType.kHead,
        t2 = 1,
    })
end

function PersonalCenterManager:hasIconHint()
    return false
end

function PersonalCenterManager:isIconCanShow()
    return true
end

--------------------------- newDressGet --------------------------------

--[[
    rewards    -- table: 奖励
    endCall    -- function: 流程结束回调
    openHonorCall    -- function: 前往荣誉展馆时发生的回调, 已删除, 参数保留
    replaceKey --str: 面板换皮的key
    panelColorType --str: 面板换色的key，与replaceKey不兼容
]]
function PersonalCenterManager:popGetNewDress(rewards)
	local ret = {
		rewards = rewards or {},
		endCallback = nil,
		openHonorCallback = nil,
		replaceKey = nil,
		panelColorType = nil,
		breakWhenAutoClose = nil,
		model = nil,
	}

	function ret:setRewards(rewards)
		self.rewards = rewards
		return self
	end

	function ret:setEndCallback(endCallback)
		self.endCallback = endCallback
		return self
	end

	function ret:setOpenHonorCallback(openHonorCallback)
		self.openHonorCallback = openHonorCallback
		return self
	end

	function ret:setReplaceKey(replaceKey)
		self.replaceKey = replaceKey
		return self
	end

	function ret:setPanelColorType(panelColorType)
		self.panelColorType = panelColorType
		return self
	end

    -- 设置UE导出的背景颜色
    -- 示例 原理上要去_UI文件里复制了填进来
    -- bg = {
    --     ColorAdjust = false,
    --     ColorMaintain = {
    --         color = {
    --             a = 255,
    --             b = 62,
    --             g = 72,
    --             r = 255,
    --         },
    --         proportion = {
    --             a = 255,
    --             b = 120,
    --             g = 120,
    --             r = 177,
    --         },
    --     },
    -- },
    function ret:setUEPanelBgColor(bg)
        self.bg = bg
        return self
    end

    -- 设置UE导出的标题颜色，分前后两层
    -- 示例
    -- titleFront = {
    --     Gradient = {
    --         BottomColor = {
    --             a = 255,
    --             b = 53,
    --             g = 237,
    --             r = 255,
    --         },
    --         TopColor = {
    --             a = 255,
    --             b = 141,
    --             g = 248,
    --             r = 255,
    --         },
    --     },
    --     OutlineColor = {
    --         a = 255,
    --         b = 51,
    --         g = 67,
    --         r = 149,
    --     },
    --     OutlineWidth = 3,
    -- },
    function ret:setUEPanelTitleColor(titleBack, titleFront)
        self.titleBack = titleBack
        self.titleFront = titleFront
        -- 去掉文案
        if self.titleBack and self.titleBack.String then
            self.titleBack.String = nil
        end
        if self.titleFront and self.titleFront.String then
            self.titleFront.String = nil
        end
        return self
    end

	function ret:setBreakWhenAutoClose(breakWhenAutoClose)
		self.breakWhenAutoClose = breakWhenAutoClose
		return self
	end

	function ret:setModel(model)
		self.model = model
		return self
	end

    local context = self
	function ret:popout()
		context:_popGetNewDress(self.rewards, self.endCallback, self.openHonorCallback, self.replaceKey, self.panelColorType, self.breakWhenAutoClose, self.model, self.bg, self.titleBack, self.titleFront)
	end

	return ret
end

function PersonalCenterManager:_popGetNewDress(rewards, endCall, openHonorCall ,replaceKey,panelColorType, breakWhenAutoClose, model, bg, titleBack, titleFront)
	--弹出获得新装扮  头像框 关卡花 头像 名片 个人状态
	local headFrameIds = {}
	local headIds = {}
	local flowerSkinIds = {}
	local nameCardIds = {}
    local playerStatusIds = {}
    local nicknameDecoIds = {}

	for i,v in ipairs(rewards) do
		--去除重复的
		if not v.duplicationSign then
			if self._propManager:isHeadFrame( v.itemId ) then
				if self._propManager:getPropIdByHeadFrameId( self._headFrameManager:getCurHeadFrame() ) == v.itemId then
					if EnvUtil:isDevelopMode() then
						setTimeOut(function()
							CommonTip:showTip("当前佩戴头像框"..v.itemId.."和获得的头像框id相同，不弹替换头像框界面了")
						end, 0)
					end
				else
					table.insert(headFrameIds,v.itemId)
				end
			elseif self._propManager:isHeadImage(v.itemId) then
				table.insert(headIds,v.itemId)
			elseif self._propManager:isFlowerSkin( v.itemId ) then
				table.insert(flowerSkinIds,v.itemId)
			elseif self._propManager:isNameCardBg( v.itemId ) then
				table.insert(nameCardIds,v.itemId)
            elseif self._propManager:isPlayerStatusProp( v.itemId ) then
				table.insert(playerStatusIds,v.itemId)
            elseif self._propManager:isNicknameDeco( v.itemId ) then
                table.insert(nicknameDecoIds,v.itemId)
            end
		end
	end

    local AsyncRunner = require "amf.script.sugar.AsyncRunner"
	local asyncRunner = AsyncRunner:create()

    if #headFrameIds>0 then
        asyncRunner:add(function (done)

			local function realDone()
				if breakWhenAutoClose then
					safeRunCall(endCall)
				else
					if done then done() end
				end
			end

            local NewHeadFrameAlertVM = require 'amf.feature.personalhub.personalcenter.view.newdressget.NewHeadFrameAlertVM'
            local params = {
                decoType = PersonalCenterConst.DecoPageSubTabType.kFrame,
            	newHeadFrameId = self._propManager:getHeadFrameId(headFrameIds[#headFrameIds]),
            	panelColorType = panelColorType,
            	closeCall = realDone,
            }
            local panel = NewHeadFrameAlertVM:create(params)
            panel:setLoadResFailCallback(realDone)
			panel:popout()
        end)
    end

    if #headIds>0 then
         asyncRunner:add(function (done)
             local function realDone()
                 if breakWhenAutoClose then
                     safeRunCall(endCall)
                 else
                     if done then done() end
                 end
             end
             local NewHeadImageAlertPanelVM = require 'amf.feature.personalhub.personalcenter.view.newdressget.NewHeadImageAlertPanelVM'
             local params = {
                decoType = PersonalCenterConst.DecoPageSubTabType.kHead,
                 newHeadImageUrl = self._propManager:getHeadImageId(headIds[#headIds]),
                 panelColorType = panelColorType,
                 closeCall = realDone,
             }
             local panel = NewHeadImageAlertPanelVM:create(params)
             panel:setLoadResFailCallback(realDone)
             panel:popout()
         end)
    end

    if #flowerSkinIds>0 then
        asyncRunner:add(function (done)
            local function realDone(context, isAutoClose)
				if breakWhenAutoClose then
					safeRunCall(endCall)
				else
					if done then done() end
				end
			end

			local NewFlowerAlertPanel = require('amf.feature.personalhub.personalcenter.view.newdressget.NewFlowerAlertVM')
			local params = {
                decoType = PersonalCenterConst.DecoPageSubTabType.kFlower,
				flowerId = flowerSkinIds[#flowerSkinIds],
				panelColorType = panelColorType,
            	closeCall = realDone,
			}
            local panel = NewFlowerAlertPanel:create(params)
            panel:setLoadResFailCallback(realDone)
			panel:popout()
        end)
    end

    if #nameCardIds>0 then
         asyncRunner:add(function (done)
             local function realDone(context, isAutoClose)
                 if breakWhenAutoClose then
                     safeRunCall(endCall)
                 else
                     if done then done() end
                 end
             end

             local NewInfoBgAlertPanelVM = require('amf.feature.personalhub.personalcenter.view.newdressget.NewInfoBgAlertPanelVM')
             local params = {
                decoType = PersonalCenterConst.DecoPageSubTabType.kNamecardBg,
                 newUserBgId = nameCardIds[#nameCardIds],
                 panelColorType = panelColorType,
                 closeCall = realDone,
             }
             local panel = NewInfoBgAlertPanelVM:create(params)
             panel:setLoadResFailCallback(realDone)
             panel:popout()
         end)
    end

    if #nicknameDecoIds>0 then
         asyncRunner:add(function (done)
            local function realDone(context, isAutoClose)
                if breakWhenAutoClose then
                    safeRunCall(endCall)
                else
                    if done then done() end
                end
            end

            local params = {
            decoType = PersonalCenterConst.DecoPageSubTabType.kNicknameDeco,
                newDecoId = nicknameDecoIds[#nicknameDecoIds],
                bg = bg,
                title_1 = titleBack,
                title_2 = titleFront,
                closeCall = realDone,
            }
             local vmCls = require("amf.feature.personalhub.personalcenter.view.newdressget.NewDressGetPanelVM")
            local vm = vmCls:create(params)
            vm:setLoadResFailCallback(realDone)
            vm:popout()
         end)
    end

    if #playerStatusIds > 0 then
        -- asyncRunner:add(function (done)
        --     local function realDone(context, isAutoClose)
		-- 		if isAutoClose and breakWhenAutoClose then
		-- 			safeRunCall(endCall)
		-- 		else
		-- 			if done then done() end
		-- 		end
		-- 	end
		-- 	if replaceKey then 	UIBuilder:setKey(replaceKey) end
        --     local NewPlayerStatusAlertPanel = require "NewPlayerStatusAlertPanel"
        --     local panel = NewPlayerStatusAlertPanel:create(playerStatusIds[#playerStatusIds], realDone, panelColorType)
        --     panel:setModel(model)
		-- 	panel:popout()
        -- end)
    end

    asyncRunner:add(function (done)
        safeRunCall(endCall)
        if done then done() end
    end)

    asyncRunner:run()

end

function PersonalCenterManager:getHasShowConcealInfoPanel()
    return self._model:getValue("hasShowConcealInfoPanel")
end

function PersonalCenterManager:setHasShowConcealInfoPanel()
    self._model:setValue("hasShowConcealInfoPanel", true)
end

function PersonalCenterManager:getRecordTipPopNum()
    return self._model:getRecordTipPopNum()
end

function PersonalCenterManager:addRecordTipPopNum(num)
    self._model:addRecordTipPopNum(num)
end

function PersonalCenterManager:createDiceNode(params)
    local DiceNode = require "amf.feature.personalhub.personalcenter.view.component.DiceNode"
    local node = DiceNode:create(params)
    return node
end

function PersonalCenterManager:checkReachDailyLikeLimit()
    local topLevel = self._levelAreaManager:getTopLevelId()
    local limits = PersonalCenterConst.DailyLikeLimit
    local limit
    for _, config in ipairs(limits) do
        if topLevel <= config.level then
            limit = config.limit
            break
        end
    end

    limit = limit or limits[#limits].limit
    local num = self:getDailyLikeNum()
    return num >= limit
end

function PersonalCenterManager:createDailyLikeLimitResp()
    local d = deferred.new()

    local RespData = require "amf.middleware.interconnection.remote.core.RespData"
    local resp = RespData.new()
    resp:setState(AMFSyncConst.RespCode.ERR_FAIL)
    local errCode = PersonalCenterConst.LIKE_LIMIT_ERROR_CODE
    resp:setData(errCode)
    resp:setErrorCode(errCode)

    d:reject(resp)
    return d
end

function PersonalCenterManager:getDailyLikeNum()
    local hasThumbsUp = self._dailyDataManager:getLocalDailyData("hasThumbsUp") or {}
    return #hasThumbsUp
end

return PersonalCenterManager
