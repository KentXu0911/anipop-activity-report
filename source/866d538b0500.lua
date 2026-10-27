local DouyinDownShowPanel = class("DouyinDownShowPanel")

function DouyinDownShowPanel:create( mgr )
	local instance = DouyinDownShowPanel.new()
	instance:init(mgr)
	return instance
end

function DouyinDownShowPanel:init( mgr )
	self.mgr = mgr
	self._lastShowDownloadTime = 0
end

function DouyinDownShowPanel:showPanel(userClick, endCallback, extra, resumeData)

    local now = TimeKit:timeInSec()
    if self._lastShowDownloadTime and (now - self._lastShowDownloadTime) < 2 then
        safeRunCall(endCallback)
        return
    end
    self._lastShowDownloadTime = now

    require 'amf.middleware.multiplatform.system.mini.bytedancetransfer.BytedanceTransferDownload'

    local giftId = self.mgr:getConst().GiftId

    if userClick then
        self.mgr:sendDC("dy_manage_download", "icon_click")
    else
        self.mgr:sendDC("dy_manage_download", "download_popup")

        local saveModel = self.mgr:getModel()
        local todayPopNum = saveModel:getPopNum()
        local newNum = todayPopNum + 1
        saveModel:setShowPanelSucess(newNum)
    end

    _G.BytedanceTransferDownload.checkDownloadGiftEnabled(giftId, {
        onSuccess = function(data)
            _G.BytedanceTransferDownload.showDownloadGift(giftId, {
                onSuccess = function()
                    safeRunCall(endCallback)
                end,
                onError = function(errCode, errMsg)
                    safeRunCall(endCallback)
                end
            })
        end,
        onError = function(errCode, errMsg)
            if userClick then
                CommonTip:showTip("活动暂不可用~")
            end
            safeRunCall(endCallback)
        end
    })
end

return DouyinDownShowPanel