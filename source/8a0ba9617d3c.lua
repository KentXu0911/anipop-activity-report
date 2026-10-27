local ResponseActShareCommonHandler = require "amf.middleware.share.openshare.handler.ResponseActShareCommonHandler"
local Handler = class("ResponseWordSpeedShareHandler", ResponseActShareCommonHandler)

function Handler:getActId()
    return DailyGiftShareConst.ACT_ID
end

function Handler:getActSource()
    return ""
end
-- 帮助次数限制
function Handler:getLimitNum()
    return 2
end

function Handler:getActName()
    return "疯狂开红包"
end

function Handler:getShareType()
    return OpenShareConst.ShareType.DAILY_GIFT
end

function Handler:preCheck(query)
    local mgr = _G.amfBean("DailyGiftShareManager")
    if not mgr or not mgr:isEnabled() then return end
    return ResponseActShareCommonHandler.preCheck(self, query)
end

function Handler:responseHelpProcess(query)
    local mgr = _G.amfBean("DailyGiftShareManager")
    if not mgr or not mgr:isEnabled() then return end
    mgr:showRequestSharePanel(query.shareKey, false)
end

return Handler