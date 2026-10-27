local BaseFeatureModel = require"amf.middleware.activity.base.BaseFeatureModel"

local LOCAL_PATH = 'amf.feature.localactivity.douyindown'

local DouyinDownModel = class("DouyinDownModel", BaseFeatureModel)

function DouyinDownModel:_getConstPath()
    return LOCAL_PATH..'.config.DouyinDownConfig'
end

function DouyinDownModel:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "DouyinDown_data"
    }):as("db")
end

function DouyinDownModel:__declare()
    self:_initLocalKey()
end

function DouyinDownModel:_initLocalKey()
	self.autoPopMainPanel = nil
    self.autoPopMainPanelDaily = nil
end

function DouyinDownModel:getPopNum(  )
	local todayPopNum = self:getFlagFromLocalByKeyInt("autoPopMainPanel", false, false)
	return todayPopNum
end

function DouyinDownModel:setShowPanelSucess( newNum )
	self:saveFlagToLocalByKeyInt("autoPopMainPanel", false, newNum, false)
    self:saveFlagToLocalByKey("autoPopMainPanelDaily", true, true)
end


function DouyinDownModel:checkCanPopMainPanel()
    local todayPopNum = self:getFlagFromLocalByKeyInt("autoPopMainPanel", false, false)
    local todayHadPop = self:getFlagFromLocalByKey("autoPopMainPanelDaily", true, false)

    if todayHadPop then return end

    if todayPopNum < self:getConst().AutoPopLimitNum then
        return true
    end
    return false
end

return DouyinDownModel
