local YYBWashingPackageConfig = require 'amf.feature.localactivity.yybwashingpackage.config.YYBWashingPackageConfig'

local DownLoadSurePanel = class("DownLoadSurePanel", AMFBasePanel)


function DownLoadSurePanel:getUIInfo()
    return "amf.feature.login.view.login.uisource.DownLoadSurePanel_UI"
end

function DownLoadSurePanel:init(...)
    self:initUI()
end

function DownLoadSurePanel:initUI()

	local str = localize("xibao_tipss6", {size = self.vm.dataSize})
	self.tip:setDimensions(CCSizeMake(410,0))
	self.tip:setString(str)

    self:initButtons()
end

function DownLoadSurePanel:initButtons()
  	self.closeBtn:setCallBack(function(argv) self:onCloseBtn(argv) end)
	self.sureLoginBtn:setCallBack(function(argv) self:onSureLoginBtn(argv) end)
end

function DownLoadSurePanel:onCloseBtn(event)
	if self.isDisposed then return end
	self:sendCommand("onCloseBtnTapped")
end

function DownLoadSurePanel:onSureLoginBtn(event)
	if self.isDisposed then
		return
	end
	safeRunCall(self.vm.sureCall )
	self:sendCommand("onCloseBtnTapped")
end

return DownLoadSurePanel
