local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local MusicMasterManager = require("amf.feature.localactivity.musicmaster.MusicMasterManager")
local MusicMasterInLevelManager = class("MusicMasterInLevelManager",BaseFeatureManager)

function MusicMasterInLevelManager:_init()
    self.actMgr = MusicMasterManager:getInstance()
    if self._autoPopupMgr then
        self.actMgr:setAutoPopupMgr(self._autoPopupMgr)
    end
end

function MusicMasterInLevelManager:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
    if self.actMgr then
        self.actMgr:setAutoPopupMgr(autoPopupMgr)
    end
end

function MusicMasterInLevelManager:isInLevelEnabled(...)
    return self.actMgr:isInLevelEnabled(...)
end

function MusicMasterInLevelManager:getInLevelActData(...)
    return self.actMgr:getInLevelActData(...)
end

function MusicMasterInLevelManager:getSlData(...)
    return self.actMgr:getSlData(...)
end

function MusicMasterInLevelManager:getPlData(...)
    return self.actMgr:getPlData(...)
end

return MusicMasterInLevelManager
