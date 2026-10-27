local DouyinDownSupport = class("DouyinDownSupport")

function DouyinDownSupport:create( mgr )
	local instance = DouyinDownSupport.new()
	instance:init(mgr)
	return instance
end

function DouyinDownSupport:init( mgr )
	self.mgr = mgr

	self.bHasSent = false --还未发送确认是否支持
	self.bGetSucceeded = false --不支持全端
end

function DouyinDownSupport:isBaseSupport()
    if not self:isPlatformSupport() then return false end
    if not self:isVersionSupport() then return false end
    if not self.mgr:getActInfo() then return false end
    return true
end

function DouyinDownSupport:isSupport()
    if not self:isBaseSupport() then return false end

    --没取就先取，取完再创建icon
    if not self.bHasSent then
        self:checkDownloadGiftEnabled()
        self.bHasSent = true
        return false
    end

    if not self.bGetSucceeded then return false end

    return true
end

function DouyinDownSupport:hasCheckedSucceeded()
    return self.bHasSent and self.bGetSucceeded
end

function DouyinDownSupport:isVersionSupport()
    local ver = tonumber(string.split(_G.bundleVersion, ".")[2])
    return ver >= self.mgr:getConst().minVer
end

function DouyinDownSupport:isPlatformSupport()
    if not ( EnvUtil:isMiniGameAndroid() and EnvUtil:isDYMiniGame() ) then return false end
    return true
end

function DouyinDownSupport:refreshActivityEntry()
    local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
    ActivityEventCenter:dispatch(ActivityEvent.UPDATE_SINGLE_ACTIVITY,{actId = self.mgr:getConst().ACT_ID})
end

function DouyinDownSupport:resetCheckState()
    self.bHasSent = false
    self.bGetSucceeded = false
end

function DouyinDownSupport:recheckDownloadGiftEnabled(callback)
    self:resetCheckState()
    self.bHasSent = true
    self:checkDownloadGiftEnabled(callback)
end

function DouyinDownSupport:checkDownloadGiftEnabled(callback)

    self.mgr:sendDC("dy_manage_download", "request")

    local giftId = self.mgr:getConst().GiftId

    CALL_EASY_JS_ASYNC(
        "globalThis.animalPlugin.sdkManager.checkDownloadGiftEnabled",
        function(result)
            local r = table.deserialize(result)
            if r and r.errCode == 0 then
                self.bGetSucceeded = true

                self:refreshActivityEntry()

                self.mgr:sendDC("dy_manage_download", "result", {t1=1})
                safeRunCall(callback, true)
            else
                self.bGetSucceeded = false
                self:refreshActivityEntry()
                self.mgr:sendDC("dy_manage_download", "result", {t1=2, t2=r and r.errCode or -1})
                safeRunCall(callback, false)
            end
        end,
        table.serialize({ giftId = giftId })
    )
end


return DouyinDownSupport
