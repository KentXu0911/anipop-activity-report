local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local MainSceneEventCenter = require "amf.feature.mainscene.core.event.MainSceneEventCenter"
local MiniAccountBindingManager = class("MiniAccountBindingManager")

local ICON_V2_EXPERIMENT_MODULE = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local ICON_V2_ASSET_PATH = "amf/accountbind/icon/phone_bind_mini_v2.png"
local ADAPTER_CREATE_READY = "ready"
local ADAPTER_CREATE_SAFE_LEGACY = "safe_legacy"
local ADAPTER_CREATE_WAIT_OWNER = "wait_owner"
local ADAPTER_STATE_NONE = "none"
local ADAPTER_STATE_V2 = "v2_mounted"
local ADAPTER_STATE_LEGACY = "legacy_mounted"
local ADAPTER_STATE_CLEANUP = "cleanup_required"
local ADAPTER_STATE_BLOCKED = "blocked"

local function isIconAlive(icon)
    if not icon or icon.isDisposed then
        return false
    end
    if type(isSafeCocosObj) == "function" then
        return isSafeCocosObj(icon)
    end
    return true
end

local function logIconV2Error(message)
    if ALog and type(ALog.strict_log_error) == "function" then
        ALog.strict_log_error("[PhoneBindMiniIconV2] " .. tostring(message))
    end
end

local function shouldRegisterPhoneBindIcon()
    -- Unity Editor uses the Browser platform define, so opt it into this icon for local UI verification.
    return EnvUtil:isUnityEditor()
        or EnvUtil:isHuaweiMiniGame()
        or EnvUtil:isALIPAYMiniGame()
        or EnvUtil:isUnionOppoMiniGame()
        or EnvUtil:isUnionMiMiniGame()
        or EnvUtil:isKuaiShouMiniGame()
        or EnvUtil:isJdMiniGame()
        or EnvUtil:isDYMiniGame()
end

local function callAdapterMethod(adapter, methodName, ...)
    local method = adapter and adapter[methodName]
    if type(method) ~= "function" then
        return false, nil, "PHONE_BIND_MINI_ICON_ADAPTER_METHOD_REQUIRED:" .. tostring(methodName)
    end
    local ok, result, detail = pcall(method, adapter, ...)
    if not ok then
        return false, nil, result
    end
    return true, result, detail
end

local function resolveAdapterState(adapter)
    if not adapter then
        return ADAPTER_STATE_NONE
    end
    local mountedOk, mounted, mountedError = callAdapterMethod(adapter, "isMounted")
    if not mountedOk then
        return ADAPTER_STATE_BLOCKED, mountedError
    end
    if mounted ~= true then
        return ADAPTER_STATE_CLEANUP
    end
    local activeOk, active, activeError = callAdapterMethod(adapter, "isV2Active")
    if not activeOk then
        return ADAPTER_STATE_BLOCKED, activeError
    end
    return active == true and ADAPTER_STATE_V2 or ADAPTER_STATE_LEGACY
end

local function getAdapterIcon(adapter)
    local called, icon, callError = callAdapterMethod(adapter, "getIcon")
    if not called then
        return nil, callError
    end
    return icon
end

local function disposeAdapter(adapter)
    local called, disposed, disposeError = callAdapterMethod(adapter, "dispose")
    if not called then
        return false, disposeError
    end
    if disposed ~= true then
        return false, disposeError or "PHONE_BIND_MINI_ICON_ADAPTER_DISPOSE_FAILED"
    end
    return true
end

local function refreshAdapter(adapter, reason, payload)
    local called, refreshed, refreshError = callAdapterMethod(adapter, "refresh", reason, payload)
    if not called then
        return false, refreshError
    end
    if refreshed == false then
        return false, refreshError
    end
    return refreshed, refreshError
end

function MiniAccountBindingManager:ctor()
    self._accountManager = nil
    self._snsBindLogic = nil
    self._stage2PopupRegistered = false
    self._v2RewardClicked = false
    self._iconAdapterRecoveryPending = false
    self._iconV2AssetReady = false
    self._iconV2AssetLoading = false
end

function MiniAccountBindingManager:isPhoneBindIconEligible()
    if EnvUtil:isUnityEditor() then
        return true
    end
    return self._snsBindLogic and self._snsBindLogic:canShowPhoneBindButton() == true
end

function MiniAccountBindingManager:_loadV2IconAsset()
    if self._iconV2AssetReady then return self:addIconIfNotExist() end
    if self._iconV2AssetLoading then return end

    self._iconV2AssetLoading = true
    _G.amfBean("AssetsUtil"):loadMiniFiles({ICON_V2_ASSET_PATH}, true):next(function()
        self._iconV2AssetLoading = false
        self._iconV2AssetReady = true
        if self:isPhoneBindIconEligible() then
            self:addIconIfNotExist()
        end
    end, function(loadError)
        self._iconV2AssetLoading = false
        logIconV2Error("asset load failed: " .. tostring(loadError))
    end)
end

function MiniAccountBindingManager:setAccountManager(aMgr)
    self._accountManager = aMgr
end

function MiniAccountBindingManager:setSnsBindLogic(logic)
    self._snsBindLogic = logic
end

-- 注入声明式强弹管理器后注册场景2入口。这里允许在依赖注入和 initialize 两处尝试注册，
-- 是为了兼容 Bean 属性注入顺序；_registerStage2Popup 会保证只注册一次。
function MiniAccountBindingManager:setAutoPopupMgr(autoPopupMgr)
	self._autoPopupMgr = autoPopupMgr
	self:_registerStage2Popup()
end

-- 抖音手机号绑定实验的场景2强弹：仅覆盖实验组且最高已过关卡不超过30关的用户。
-- 是否已绑定、平台审核态和功能开关继续由 SnsBindLogic 统一判断，避免这里复制完整准入规则。
-- onPopOver 必须透传给输入及后续结果面板，最终关闭后由声明式强弹框架继续调度后续弹窗。
function MiniAccountBindingManager:_registerStage2Popup()
	local popupFlag = EnvUtil:isHuaweiMiniGame() or EnvUtil:isALIPAYMiniGame() or EnvUtil:isUnionOppoMiniGame() or EnvUtil:isUnionMiMiniGame() or EnvUtil:isKuaiShouMiniGame() or EnvUtil:isJdMiniGame() or EnvUtil:isDYMiniGame()
	if not popupFlag then
		return
	end
	if self._stage2PopupRegistered then return end
	if not self._autoPopupMgr or not self._snsBindLogic then return end

	require "amf.middleware.autopop.config.AutoPopupConst"
	self._autoPopupMgr:registerPopup({
		checkPoint = PopupCheckPoint.DY_PHONE_BIND_STAGE2,
		stages = {AutoPopupConst.PopStage.STAGE_TWO},
		check = function()
			if _G.getTopPassedLevelId() > 30 then return false end
			if not self._snsBindLogic:isDyPhoneBindExperimentEnabled() then return false end
			return self._snsBindLogic:canShowPhoneBindButton()
		end,
		creator = function(_, onPopOver)
			return function()
				self._snsBindLogic:onPhoneBindButtonTapped(true, onPopOver)
			end
		end,
	})
	self._stage2PopupRegistered = true
end

function MiniAccountBindingManager:initialize()
    self._dc = require "amf.feature.accountbind.minibind.dc.MiniBindDc"
	self:_registerStage2Popup()

    ---大藤蔓干掉按钮,现在只有支付宝小程序  和oppo小程序有
    if shouldRegisterPhoneBindIcon() then
        IconEventCenter:register(IconEvent.ICON_SYSTEM_READY, self.onIconSystemReady, self)
    end
    if EnvUtil:isUnityEditor() then
        -- The Editor can initialize this bean after ICON_SYSTEM_READY has already been dispatched.
        setTimeOut(function()
            self:onIconSystemReady()
        end, 0, "MiniAccountBindingManager.EditorIconMock")
    end
    _G.amfEC:registerFeature(self)
end

function MiniAccountBindingManager:getDc()
    return self._dc
end

function MiniAccountBindingManager:tryRefreshIcon()
    if not EnvUtil:isUnity() then return end
    if self:isPhoneBindIconEligible() then
        if self._iconAdapterRecoveryPending then
            return self:addIconIfNotExist()
        end
        if self.iconAdapter then
            local adapterState = resolveAdapterState(self.iconAdapter)
            if adapterState == ADAPTER_STATE_V2 then
                return self:refreshV2Icon("business_refresh")
            end
            if adapterState == ADAPTER_STATE_LEGACY then
                return IconEventCenter:refreshIconEvent(IconKey.kPhoneBind)
            end
            return self:addIconIfNotExist()
        end
        if self._iconAdapterRecoveryPending then
            return self:addIconIfNotExist()
        end
        return IconEventCenter:refreshIconEvent(IconKey.kPhoneBind)
    end
end

function MiniAccountBindingManager:tryRemoveIcon()
    if not EnvUtil:isUnity() then return end
    if not self:isPhoneBindIconEligible() then
        return self:removeIcon()
    end
end

function MiniAccountBindingManager:onUserTopLevelChanged()
    self:tryRefreshIcon()
end

function MiniAccountBindingManager:_registerV2LabelRefresh()
    if self._v2LabelRefreshRegistered then
        return
    end
    MainSceneEventCenter:unregisterGlobal(NormalEvent.USER_TOP_LEVEL_CHANGED, self)
    MainSceneEventCenter:registerGlobal(NormalEvent.USER_TOP_LEVEL_CHANGED, self.onUserTopLevelChanged, self)
    self._v2LabelRefreshRegistered = true
end

function MiniAccountBindingManager:_unregisterV2LabelRefresh()
    if not self._v2LabelRefreshRegistered then
        return
    end
    MainSceneEventCenter:unregisterGlobal(NormalEvent.USER_TOP_LEVEL_CHANGED, self)
    self._v2LabelRefreshRegistered = false
end

function MiniAccountBindingManager:getIconLabel()
    if _G.getTopPassedLevelId() >= 1999 then
        return "绑定手机号"
    end
    return "找回老账号"
end

function MiniAccountBindingManager:hasV2RewardClicked()
    return self._v2RewardClicked == true
end

function MiniAccountBindingManager:markV2RewardClicked()
    self._v2RewardClicked = true
    return true
end

function MiniAccountBindingManager:isV2IconExperimentEnabled()
    if EnvUtil:isUnityEditor() then
        return true
    end
    local ok, enabled = pcall(function()
        local experiment = require(ICON_V2_EXPERIMENT_MODULE)
        return experiment:isEnabled()
    end)
    return ok and enabled == true
end

function MiniAccountBindingManager:createLegacyIcon()
    local PhoneBindIcon = require "amf.feature.accountbind.minibind.icon.PhoneBindIcon"
    return PhoneBindIcon:create(function()
        self._snsBindLogic:onPhoneBindButtonTapped()
    end)
end

function MiniAccountBindingManager:createPackageIconAdapter()
    local adapterLoaded, PackageIconV2Adapter = pcall(
        require,
        "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Adapter"
    )
    if not adapterLoaded then
        return {
            state = ADAPTER_CREATE_SAFE_LEGACY,
            error = PackageIconV2Adapter,
        }
    end
    if type(PackageIconV2Adapter.create) ~= "function" then
        return {
            state = ADAPTER_CREATE_SAFE_LEGACY,
            error = "PHONE_BIND_MINI_ICON_V2_ADAPTER_CREATE_REQUIRED",
        }
    end

    local ownerIconKey = IconKey.kPhoneBind
    local configOk, options, provider = pcall(function()
        local IconV2Config = require "amf.feature.accountbind.minibind.icon.IconV2Config"
        local configOptions, configProvider = IconV2Config.create(self, IconEventCenter)
        assert(type(configOptions) == "table", configProvider or "PHONE_BIND_MINI_ICON_V2_CONFIG_REQUIRED")
        return configOptions, configProvider
    end)
    if not configOk then
        local configError = options
        options = {
            ownerIconKey = ownerIconKey,
            iconEventCenter = IconEventCenter,
            legacyFactory = function()
                return self:createLegacyIcon()
            end,
            v2PreflightError = configError,
        }
        provider = nil
    end

    local createOk, adapter, modeOrError, cleanupOwner = pcall(
        PackageIconV2Adapter.create,
        PackageIconV2Adapter,
        options
    )
    if not createOk then
        return {
            state = ADAPTER_CREATE_WAIT_OWNER,
            error = adapter,
        }
    end
    if not adapter then
        return {
            state = ADAPTER_CREATE_WAIT_OWNER,
            error = modeOrError,
            cleanupOwner = cleanupOwner,
        }
    end
    return {
        state = ADAPTER_CREATE_READY,
        adapter = adapter,
        provider = provider,
        mode = modeOrError,
    }
end

function MiniAccountBindingManager:_adoptIconAdapter(adapter, provider, recoveryPending)
    self.iconAdapter = adapter
    local adapterState, stateError = resolveAdapterState(adapter)
    local icon, iconError = getAdapterIcon(adapter)
    self.icon = icon
    self.iconDataProvider = adapterState == ADAPTER_STATE_V2 and provider or nil
    self._iconAdapterRecoveryPending = recoveryPending == true
        or adapterState == ADAPTER_STATE_CLEANUP
        or adapterState == ADAPTER_STATE_BLOCKED
        or iconError ~= nil
    if stateError then
        logIconV2Error("adapter state failed: " .. tostring(stateError))
    end
    if iconError then
        logIconV2Error("adapter icon failed: " .. tostring(iconError))
    end
    if adapterState == ADAPTER_STATE_V2 then
        self:_registerV2LabelRefresh()
    else
        self:_unregisterV2LabelRefresh()
    end
end

function MiniAccountBindingManager:_disposeIconAdapter()
    local adapter = self.iconAdapter
    if not adapter then
        return true
    end
    local disposed, disposeError = disposeAdapter(adapter)
    if not disposed then
        local icon, iconError = getAdapterIcon(adapter)
        if not iconError then
            self.icon = icon
        end
        self._iconAdapterRecoveryPending = true
        logIconV2Error("dispose failed: " .. tostring(disposeError or iconError))
        return false, disposeError or iconError
    end
    self.iconAdapter = nil
    self.iconDataProvider = nil
    self.icon = nil
    self._iconAdapterRecoveryPending = false
    self:_unregisterV2LabelRefresh()
    return true
end

function MiniAccountBindingManager:_recoverPendingIconAdapter()
    if not self._iconAdapterRecoveryPending or not self.iconAdapter then
        return true
    end
    return self:_disposeIconAdapter()
end

function MiniAccountBindingManager:addIconIfNotExist()
    local recovered = self:_recoverPendingIconAdapter()
    if recovered == false then
        return self.icon
    end
    if self.iconAdapter then
        local adapterState, stateError = resolveAdapterState(self.iconAdapter)
        if adapterState == ADAPTER_STATE_V2 or adapterState == ADAPTER_STATE_LEGACY then
            local icon, iconError = getAdapterIcon(self.iconAdapter)
            if iconError then
                self._iconAdapterRecoveryPending = true
                logIconV2Error("mounted adapter icon failed: " .. tostring(iconError))
                return self.icon
            end
            self.icon = icon
            self._iconAdapterRecoveryPending = false
            return self.icon
        end
        if stateError then
            logIconV2Error("adapter state failed before recovery: " .. tostring(stateError))
        end
        local disposed = self:_disposeIconAdapter()
        if disposed == false then
            return self.icon
        end
    end
    if isIconAlive(self.icon) then
        return self.icon
    end

    if self:isV2IconExperimentEnabled() or self._iconAdapterRecoveryPending then
        if not self._iconV2AssetReady and EnvUtil:isUnity() then
            return self:_loadV2IconAsset()
        end
        local createResult = self:createPackageIconAdapter()
        local ownerAdapter = createResult.adapter or createResult.cleanupOwner
        if ownerAdapter then
            self:_adoptIconAdapter(
                ownerAdapter,
                createResult.provider,
                createResult.state == ADAPTER_CREATE_WAIT_OWNER
            )
            if not createResult.adapter then
                logIconV2Error("create pending cleanup: " .. tostring(createResult.error))
            end
            return self.icon
        end
        if createResult.state ~= ADAPTER_CREATE_SAFE_LEGACY then
            self._iconAdapterRecoveryPending = true
            logIconV2Error("create waiting for owner recovery: " .. tostring(createResult.error))
            return nil
        end
        self._iconAdapterRecoveryPending = false
        logIconV2Error("adapter unavailable, fallback legacy: " .. tostring(createResult.error))
    end

    self._iconAdapterRecoveryPending = false
    self.icon = self:createLegacyIcon()
    self:_unregisterV2LabelRefresh()
    IconEventCenter:addIconEvent(self.icon)
    return self.icon
end

function MiniAccountBindingManager:removeIcon()
    if self.iconAdapter then
        return self:_disposeIconAdapter()
    end

    if isIconAlive(self.icon) then
        IconEventCenter:removeIconEvent(IconKey.kPhoneBind)
    else
        local iconManager = _G.amfBean and _G.amfBean("IconManager")
        local existing = iconManager and iconManager:getIconByIconKey(IconKey.kPhoneBind)
        if existing and not existing.isDisposed then
            IconEventCenter:removeIconEvent(IconKey.kPhoneBind)
        end
    end
    self.icon = nil
    self._iconAdapterRecoveryPending = false
    self:_unregisterV2LabelRefresh()
    return true
end

function MiniAccountBindingManager:refreshV2Icon(reason, payload)
    local adapterState = resolveAdapterState(self.iconAdapter)
    if adapterState ~= ADAPTER_STATE_V2 then
        return false
    end
    local refreshed, refreshError = refreshAdapter(self.iconAdapter, reason, payload)
    if refreshed == false then
        logIconV2Error("refresh failed: " .. tostring(refreshError))
    end
    return refreshed, refreshError
end

function MiniAccountBindingManager:onActEnterMainScene(evt)
    if not EnvUtil:isUnity() then return end
    self:tryRemoveIcon()

    -- self:tryAutoPopup(evt:getData())
end

function MiniAccountBindingManager:tryAutoPopup(data)
    --弹过了不弹
    -- if _G.amfBean("AutoPopupMgr"):getPermanentShowNum("PhoneBindPopup") > 0 then
    --     return
    -- end

    -- -- --首次进入不弹
    -- if data.firstEnter and self._snsBindLogic:checkCanPopInStage2() then return end
    -- if not self._snsBindLogic:canShowPhoneBindButton() then return end

    -- local function onHandleOver()
	-- 	AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.BIND_PHONE)
	-- end

    -- local function creator()
    --     if not self._snsBindLogic:canShowPhoneBindButton() then 
    --         onHandleOver()
    --         return 
    --     end

    --     _G.amfBean("AutoPopupMgr"):sendPermanentData("PhoneBindPopup")
    --     _G.amfBean("AutoPopupMgr"):resetPopup()
    --     self._snsBindLogic:onPhoneBindButtonTapped(false)
    -- end
    
    -- _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.BIND_PHONE, creator)
end

---场景4强弹 ,目前只有支付宝抖音有
function MiniAccountBindingManager:onActEnterStage4(evt)

    local popupFlag = EnvUtil:isHuaweiMiniGame() or EnvUtil:isALIPAYMiniGame() or EnvUtil:isUnionOppoMiniGame() or EnvUtil:isUnionMiMiniGame()  or EnvUtil:isKuaiShouMiniGame() or EnvUtil:isJdMiniGame() or EnvUtil:isDYMiniGame()
    if not popupFlag then
        return
    end

	-- 实验组的0～30关用户已改由场景2每日触发，场景4必须跳过，避免同一次登录出现两个手机号绑定强弹。
	-- 31～1998关仍沿用原场景4和 phone_bind_popup 终身一次标记；OFF组也保持原行为。
	if self._snsBindLogic:isDyPhoneBindExperimentEnabled() and _G.getTopPassedLevelId() <= 30 then
		return
	end

    if not self._snsBindLogic:canShowPhoneBindButton() then
        return
    end
    local isAlreadyPop = UserManager:getInstance():getClientCustomData("phone_bind_popup") ---永久弹一次，是否弹过的标识
    if isAlreadyPop ~= nil then
        return
    end
    local function onHandleOver()
        --UWarning("MiniAccountBindingManager onActEnterStage4 onHandleOver")
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.PHONE_BIND)
    end
    local function creator()
        --UWarning("MiniAccountBindingManager onActEnterStage4 creator")
        self._snsBindLogic:onPhoneBindButtonTapped(true,onHandleOver)
        UserManager:getInstance():setClientCustomDataHttp("phone_bind_popup",true)
    end
    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.PHONE_BIND, creator)
end

function MiniAccountBindingManager:canGetPhoneNumber()
    if EnvUtil:isALIPAYMiniGame() then
        if UserManager:getClientCustomData("phone_bind_aliApiQueryBanned") then
            return false
        end
        local todayDay = getDayIndexByTs(TimeKit:timeInSec())
        local num = UserManager:getClientCustomData("phone_bind_aliApiQueryToday")
        if num and todayDay == tonumber(num) then
            return false
        end
        return true
    ---微信的快速验证只有ios支持，微信那客服那头反馈的,如果将来支持了安卓PhoneBindLogic:addTouchListener()注册和去掉的ios判断也删掉
    elseif EnvUtil:isWXMiniGame() and EnvUtil:isMiniGameIOS() then
        local canGetPhoneNumber = CS.CallJS.InvokeSync("globalThis.animalPlugin.sdkManager.isInterfaceAvailable","getPhoneNumber")
        return table.deserialize(canGetPhoneNumber)
    end

    return false
end

function MiniAccountBindingManager:onIconSystemReady()
    if self:isPhoneBindIconEligible() then
        self:addIconIfNotExist()
    else
        self:removeIcon()
    end
end

-- 打点
function MiniAccountBindingManager:dc(category, subCategory, t1, t2, t3, t4, extraData)
    local params = {
        category = category,
        sub_category = subCategory,
        -- panel_id = panel_id,
        t1 = t1,
        t2 = t2,
        t3 = t3,
        t4 = t4,
    }

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end

    DcUtil:UserTrack(params)
end


return MiniAccountBindingManager
