require "amf.middleware.setting.option.widescreen.config.WideScreenConst"
local WideScreenLogic = class("WideScreenLogic")
local deferred = require "amf.script.sugar.deferred"
local Const = WideScreenConst

function WideScreenLogic:ctor(delegate, settingMgr)
    self.deviceInfoDelegate = delegate
    self.settingMgr = settingMgr
end

function WideScreenLogic:init()
    self:updateData()
    _G.amfEC:registerSystem(self)
    _G.amfEC:registerFeature(self)
    _G.registerWindowSizeChangeCallback(function()
        self:onSizeChange()
    end)
end

local function isNaN(v)
    return v ~= v
end

local function safeAspectFlag(w, h)
    if h == 0 then return false end
    return w >= Const.ASPECT_RATIO * h
end

function WideScreenLogic:updateData()
    if not self:isPlatformSupport() then return end
    local data = self:getData()
    local key = self:getScreenKey()

    if data[key] then return end

    data[key] = {
        initialType = Const.SHOW_TYPE.SMALL,
        nowType = self:isExpand() and Const.SHOW_TYPE.BIG
            or Const.SHOW_TYPE.SMALL
    }
    local view = CCDirector:sharedDirector():getOpenGLView()
    local curA = view:getDesignResolutionSize()
    local minA = view:get_minimum_design_size()
    local maxA = view:get_maximum_design_size()

    --防止NAN
    if isNaN(curA.height) or isNaN(minA.height) or isNaN(maxA.height) then
        return
    end
    local canExpand = curA.width > minA.width
    local meetAspectRatio = safeAspectFlag(curA.width, curA.height)
    local baseRatio = (maxA.width == minA.width) and 1
        or (curA.width - minA.width) / (maxA.width - minA.width)

    data[key] = {
        initialType = Const.SHOW_TYPE.SMALL,
        nowType = self:isExpand() and Const.SHOW_TYPE.BIG or Const.SHOW_TYPE.SMALL,
        canExpand = canExpand,
        meetAspectRatio = meetAspectRatio,
        baseRatio = baseRatio,
    }
    self:setData(data)

    if data[key].nowType == Const.SHOW_TYPE.SMALL then
        self:changeToOriginState()
    else
        self:changeToUserSetState()
    end
end

function WideScreenLogic:onSizeChange()
    self:updateData()
end

function WideScreenLogic:onSystemEnterForeground()
    self:updateData()
end

function WideScreenLogic:onActEnterStage2()
    self:tryAddPop()
end

function WideScreenLogic:isEnabled()
    if not self:isPlatformSupport() then return false end

    local d = self:getNowSizeData()
    return d and d.meetAspectRatio and d.canExpand
end

function WideScreenLogic:isPlatformSupport()
    if PlatformConfig:isPlayDemo() or EnvUtil:isMiniGame() or EnvUtil:isStandalone() then
        return false
    end

    return true
end

function WideScreenLogic:getBaseRatio()
    local data = self:getNowSizeData()
    return data and data.baseRatio or 1
end

function WideScreenLogic:getData()
    return self.settingMgr:getModelData("wideScreen")
end

function WideScreenLogic:setData(data)
    self.settingMgr:setModelData("wideScreen", data)
end

function WideScreenLogic:getNowSizeData()
    local data = self:getData()
    return data[self:getScreenKey()]
end

function WideScreenLogic:getScreenKey()
    local frameSize = CCDirector:sharedDirector():getOpenGLView():getFrameSize()
    local base = ("%dx%d"):format(frameSize.width, frameSize.height)
    return base .. "_" .. (self:isExpand() and "E" or "NE")
end

function WideScreenLogic:isExpand()
    return self.deviceInfoDelegate:isExpand()
end

function WideScreenLogic:getInitialType()
    return self:getNowSizeData().initialType
end

function WideScreenLogic:getUserNowType()
    return self:getNowSizeData().nowType
end

function WideScreenLogic:changeDisplayMode(displayMode)
    if not self:isEnabled() then return deferred.error() end
    if self:getInitialType() == displayMode then
        self:changeToOriginState()
    else
        self:changeToUserSetState()
    end

    local data = self:getData()
    local key = self:getScreenKey()
    if data[key].nowType ~= displayMode then
        data[key].nowType = displayMode
        self:setData(data)
        return deferred.success()
    else
        return deferred.error()
    end
end

function WideScreenLogic:changeToOriginState()
    self:setUserResolution(self:getBaseRatio())
    CCDirector:sharedDirector():getOpenGLView():refreshResolution()
end

local function getSettingPath()
    return HeResPathUtils:getUserDataPath() .. "/eglview.user.setting"
end

function WideScreenLogic:changeToUserSetState()
    self:setUserResolution(self:getUserCanSetResolution())
    CCDirector:sharedDirector():getOpenGLView():loadUserSetting(getSettingPath())
    CCDirector:sharedDirector():getOpenGLView():refreshResolution()
end

function WideScreenLogic:getUserCanSetResolution()
    local view = CCDirector:sharedDirector():getOpenGLView()
    local cur = view:getDesignResolutionSize()
    local min = view:get_minimum_design_size()
    local max = view:get_maximum_design_size()

    local minW, nowW, maxW = min.width, cur.width, max.width
    local useW
    if self:getInitialType() == Const.SHOW_TYPE.SMALL then
        useW = math.max(nowW / Const.MAX_CHANGE_RATIO, minW)
    else
        useW = math.min(nowW * Const.MAX_CHANGE_RATIO, maxW)
    end

    local ratio = (useW - minW) / (maxW - minW)
    return ratio
end

function WideScreenLogic:setUserResolution(num)
    local view = CCDirector:sharedDirector():getOpenGLView()
    view:setUserSettingResolution(tonumber(num))
    view:saveUserSetting(getSettingPath())
end

-- Autopop
function WideScreenLogic:tryAddPop()
    if not self:isEnabled() or self:hasPopped() then return end

    local key = PopupCheckPoint.WIDE_SCREEN_ADVICE

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, key)
    end

    local creator = function ( ... )
        if not self:isEnabled() then
            onHandleOver()
            return
        end
        _G.amfBean("AutoPopupMgr"):sendPermanentData(key)
        self:openNoticePanel(onHandleOver)
    end

    _G.amfBean("AutoPopupMgr"):addPopupConfig(key, creator)
end

function WideScreenLogic:hasPopped()
    return _G.amfBean("AutoPopupMgr"):getPermanentShowNum(_G.PopupCheckPoint.WIDE_SCREEN_ADVICE) >= 1
end

function WideScreenLogic:openNoticePanel(closeCallback)
    local VM = require "amf.middleware.setting.option.widescreen.view.WideScreenNoticePanelVM"
    local vm = VM.Builder.new()
        :setCloseCallback(closeCallback)
        :setLoadResFailCallback(closeCallback)
        :build()
    vm:popout()
end

function WideScreenLogic:openDisplaySettingPanel()
    local d = deferred.new()

    local VM = require "amf.middleware.setting.option.widescreen.view.DisplaySettingPanelVM"
    local vm = VM.Builder.new()
        :setCloseCallback(function()
            d:resolve(false)
        end)
        :setLogic(self)
        :build()
    vm:popout()
    return d
end

function WideScreenLogic:resetResolution()
    local view = CCDirector:sharedDirector():getOpenGLView()
    view:resetUserSetting()
    view:refreshResolution()
end

return WideScreenLogic
