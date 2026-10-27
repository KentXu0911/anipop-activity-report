
local YYBWashingPackageConfig = require 'amf.feature.localactivity.yybwashingpackage.config.YYBWashingPackageConfig'
local YYBWashingPackageDC = require 'amf.feature.localactivity.yybwashingpackage.dc.YYBWashingPackageDC'
local YYBWashingPackageModel = require 'amf.feature.localactivity.yybwashingpackage.model.YYBWashingPackageModel'
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"

local privateNS = {}

local YYBWashingPackageManager = class("YYBWashingPackageManager")

local bShowLog = YYBWashingPackageConfig.bShowLog
local function showLog( ... )
    if EnvUtil:isDevelopMode() and bShowLog then
        printx(12,"***yyb洗包***", ...)
    end
end

function YYBWashingPackageManager:initialize()
	self.maintenanceIsOpen = true

    self.dcUtil = YYBWashingPackageDC

	-- local maintenanceName = 'yyb_flush'
    -- local uid = UserManager:getInstance().user.uid or '12345'
	-- self.maintenanceIsOpen = MaintenanceManager:getInstance():isEnabledInGroup( maintenanceName , "ON" , uid )

    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
end

function YYBWashingPackageManager:initModel()
    --model要在user后初始化，所以放在了需要检测可以弹出面板的地方，都在user后
    if not privateNS.model then
        privateNS.model = YYBWashingPackageModel:create()
    end
end

function YYBWashingPackageManager:onActActInfoUpdate(event)

    if EnvUtil:isMiniGame() then return end

    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer

    --test    
    -- fromServer = true
    -- local actInfo = {
    --     actId = 9076,
    --     beginTime = "0",
    --     clickNum = "0",
    --     extra = '{"actEndTime":1795658400000,"heVersion":"1.151","endTime":0,"heUpdateUrl":"http://downloadapkmanimal.happyelements.cn/apk/154b5cd356f6e532db0a46ff4cc9c412.apk"}',
    --     maxProgress = 0,
    --     msgNum = 0,
    --     progress = 0,
    --     rank = 0,
    --     reward = false,
    --     rewardFlag = 0,
    --     see = true,
    --     specialBanActivity = false,
    -- }

    if fromServer then
        local actInfo = actInfos[tostring(YYBWashingPackageConfig.actId)]
        if actInfo then
            self:saveActInfo(actInfo)
        else
            --清活动
            self:saveActInfo()
        end
    end
end

function YYBWashingPackageManager:getActInfo()
    self:initModel()

    local actInfo = privateNS.model:getSaveActInfo()
    return actInfo
end

function YYBWashingPackageManager:saveActInfo(actInfo)
    self:initModel()

    privateNS.model:setSaveActInfo(actInfo)
end

function YYBWashingPackageManager:isUnSupportPkg()
    if EnvUtil:isPrePackage() then
        return true
    end

    local yybPlatFormList = {
        PlatformNameEnum.kQQ,
        PlatformNameEnum.kYYB_CENTER,
        PlatformNameEnum.kYYB_MARKET,
        PlatformNameEnum.kYYB_JINSHAN,
        PlatformNameEnum.kYYB_BROWSER,
        -- PlatformNameEnum.kYYB_ZONE,
        PlatformNameEnum.kYYB_VIDEO,
        PlatformNameEnum.kYYB_NEWS,
        PlatformNameEnum.kYYB_QQ,
        -- PlatformNameEnum.kYYB_PC,
        PlatformNameEnum.kYYB_CORE,
        PlatformNameEnum.kYYB_SHOP,
        PlatformNameEnum.kYYB_TMS_CENTER,
        PlatformNameEnum.kYYB_TMS_SHOP,
        PlatformNameEnum.KYYB_MANAGER,
        PlatformNameEnum.kYYB_TONGXIN,
    }

    -- showLog( "PlatformConfig.name", _G._PLATFORM_NAME )

    local isSupportPlatForm = false
    for i,v in ipairs(yybPlatFormList) do
        if PlatformConfig:isPlatform(v) then
            isSupportPlatForm = true
            break
        end
    end

    return not isSupportPlatForm
end

function YYBWashingPackageManager:canOpenYYBUpdatePanel()
	--提审、 actInfo，passLevel, platForm,
    --版本号，平台 后端判断
    --test
    -- do return true end
    if EnvUtil:isMiniGame() then return false end
    showLog("canOpenYYBUpdatePanel 111111111")
	if MaintenanceManager.getInstance():isInReview() then return false end
    showLog("canOpenYYBUpdatePanel 222222222")
	if self:isUnSupportPkg() then return false end
    showLog("canOpenYYBUpdatePanel 333333333")
	if not self:getActInfo() then return false end
    showLog("canOpenYYBUpdatePanel 4444444444")
    if not self:isEnabled() then return false end
    showLog("canOpenYYBUpdatePanel 55555")
	if not self.maintenanceIsOpen then return false end
    showLog("canOpenYYBUpdatePanel 6666")
	local passedLevel = _G.getTopPassedLevelId()
    if passedLevel < YYBWashingPackageConfig.openPassLevel then
        return false
    end
    showLog("canOpenYYBUpdatePanel 777777")
    return true
end

function YYBWashingPackageManager:isEnabled()
    local endTime = self:getEndTime()
    local curTime = TimeKit:timeInSec()
    if curTime > endTime then
        return false
    end
    return true
end

function YYBWashingPackageManager:getEndTime()
    local actInfo = self:getActInfo()
    if actInfo then
        local extraConfig = table.deserialize(actInfo.extra)
        local endTime = math.ceil2(tonumber(extraConfig.endTime)/1000)
        local actEndTime = math.ceil2(tonumber(extraConfig.actEndTime)/1000)
        if endTime == 0 then
            return actEndTime
        else
            return endTime
        end
    end
    return -1
end

function YYBWashingPackageManager:openYYBUpdatePanel( userClick, endCallback, extra )
    local YYBUpdatePanelVM = require 'amf.feature.localactivity.yybwashingpackage.view.YYBUpdatePanelVM'
	local panel = YYBUpdatePanelVM:create( {userClick = userClick, closeCallBack = endCallback, extra = extra} )
	panel:popout()

    local endTime = self:getEndTime()
    if endTime > 0 then
        local function passActEndCall()
            CommonTip:showTip('活动已结束')
        end
        panel:setActEndTime( self:getEndTime()*1000, passActEndCall )
    end
end

function YYBWashingPackageManager:checkYYBAppIsInstall()
	return self:canOpenUrl( YYBWashingPackageConfig.yybScheme )
end

function YYBWashingPackageManager:openYYBApp()
	self:openUrl( YYBWashingPackageConfig.yybScheme )
end

function YYBWashingPackageManager:canOpenUrl( schemeName )
	if __ANDROID then
		local status, result = pcall(function() return luajava.bindClass("com.happyelements.android.utils.HttpUtil"):canOpenUrl(schemeName) end)
		return status and result
	end

	return false 
end

function YYBWashingPackageManager:openUrl( schemeName )
	if __ANDROID then
		local status, result = pcall(function() return luajava.bindClass("com.happyelements.android.utils.HttpUtil"):openUri(schemeName) end)
		return status and result
	end

	return false 
end

return YYBWashingPackageManager
