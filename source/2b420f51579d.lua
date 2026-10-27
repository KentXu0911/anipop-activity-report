
local OutsideHandler = class("OutsideHandler")

function OutsideHandler:create(autoPopupMgr)
	local handler = OutsideHandler.new()
	handler:init(autoPopupMgr)
	return handler
end

function OutsideHandler:init(autoPopupMgr)
	self._autoPopupMgr = autoPopupMgr
	AutoPopEventCenter:register(AutoPopEvent.OUTSIDE, self.onHandlePopup, self)
end

function OutsideHandler:onHandlePopup(evt)
	local data = evt:getData()
	local popupCheckPoint = data.popupCheckPoint
	local params = data.params

	lua_switch(popupCheckPoint){
		[PopupCheckPoint.CLICK_LINK_BIND_WECHAT_PAY] = function ()
			self:handleClickBindWechatPay(params)
		end,
        [PopupCheckPoint.CLICK_LINK_WECHAT_FAQ] = function ()
            self:handleClickLinkWechatFAQ(params)
        end,
		default = function ()
			assert(false, "OutsideHandler invalid popupCheckPoint : " .. tostring(popupCheckPoint))
		end
	}
end

function OutsideHandler:handleClickBindWechatPay(params)
    local url = params.url
	local para = url.para
    
    local openId = para.openId
    local app = para.app
    local redirect = para.redirect

    local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.CLICK_LINK_BIND_WECHAT_PAY)
	end

	local function creator()
		local function showResult()
			local resultUrl = HeDisplayUtil:urlDecode(redirect);
			local TextUtil = require "amf.middleware.ui.util.TextUtil"
			resultUrl = TextUtil:buildURL("", resultUrl, {
				app = app,
				openId = openId,
				userId = _G.amfBean("ProfileManager"):getXxlId(),
			});
	
			local OpenUrlUtil = require "amf.middleware.multiplatform.util.OpenUrlUtil"
			OpenUrlUtil:openUrl(resultUrl)
		end
        local request = require "amf.middleware.autopop.module.openurl.http.RequestOfficialPayBindWx"
		request:post({openId = openId}):next(showResult, showResult)

		onHandleOver()
	end
	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.CLICK_LINK_BIND_WECHAT_PAY, creator)
end

function OutsideHandler:handleClickLinkWechatFAQ(params)
    local url = params.url

	--never use by now
	local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.CLICK_LINK_WECHAT_FAQ)
	end

	local function creator()
		FAQ:openFAQClient(url, FAQTabTags.kSheQu, true)

		--这个绑定需打开社区，保险起见，停掉强弹
		self._autoPopupMgr:resetPopup()
	end
	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.CLICK_LINK_WECHAT_FAQ, creator)
end

return OutsideHandler