local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"

local DouyinDownSupport =	require"amf.feature.localactivity.douyindown.module.DouyinDownSupport"
local DouyinDownShowPanel =	require"amf.feature.localactivity.douyindown.module.DouyinDownShowPanel"

local LOCAL_PATH = 'amf.feature.localactivity.douyindown'

local DouyinDownManager = class("DouyinDownManager",BaseFeatureManager)

function DouyinDownManager:_init()

	ActivityEventCenter:registerGlobal(NormalEvent.PAYMENT_SUCCESS, self.onOrderSuccess, self)

    self.douyinDownSupport = DouyinDownSupport:create(self)
    self.douyinDownShowPanel = DouyinDownShowPanel:create(self)
end

function DouyinDownManager:_getModelPath()
    return LOCAL_PATH..'.model.DouyinDownModel'
end

function DouyinDownManager:_getConstPath()
    return LOCAL_PATH..'.config.DouyinDownConfig'
end

function DouyinDownManager:isSupport()
    return self.douyinDownSupport:isSupport()
end

function DouyinDownManager:showPanel(userClick, endCallback, extra, resumeData)
	self.douyinDownShowPanel:showPanel( userClick, endCallback, extra, resumeData )
end

function DouyinDownManager:getActInfo()
	return _G.amfBean("ActivityMgr"):getActInfo( self:getConst().ACT_ID )
end

function DouyinDownManager:isInMainScene()
    local scene = Director:sharedDirector():getRunningSceneLua()
    if not scene then return false end
    if not scene:isScene("MainScene") then return false end
    return true
end

function DouyinDownManager:showPanelOnMainScene(userClick, endCallback, extra, resumeData)
    if not self:isInMainScene() then
        safeRunCall(endCallback)
        return
    end
    if not self:getModel():checkCanPopMainPanel() then
        safeRunCall(endCallback)
        return
    end
    self:showPanel(userClick, endCallback, extra, resumeData)
end

-- 购买成功
function DouyinDownManager:onOrderSuccess(event)
    local data = event:getData()
    if not data or not data.goodsId then return end

    local goodsId = data.goodsId
    local payType = data.payType
    local isRmb = data.isRmb
    if not isRmb then return end
    if not self.douyinDownSupport:isBaseSupport() then return end

    if self.douyinDownSupport:hasCheckedSucceeded() then
        self:showPanelOnMainScene(false)
        return
    end

    self.douyinDownSupport:recheckDownloadGiftEnabled(function(succeeded)
        if succeeded then
            self:showPanelOnMainScene(false)
        end
    end)
end

function DouyinDownManager:sendDC(category, subCategory, extraData)
    self:dcUserTrack(category, subCategory, extraData)
end

return DouyinDownManager
