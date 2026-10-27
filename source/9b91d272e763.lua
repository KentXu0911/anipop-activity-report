local AbstractPlug = require "amf.script.pattern.plug.AbstractPlug"

local AutoPopPlug = class("AutoPopPlug", AbstractPlug)

function AutoPopPlug:onInstall()
    self.registeredCheckPoints = {}

    if self.hostObj and self.hostObj.autoPopupMgr then
        self:setAutoPopupMgr(self.hostObj.autoPopupMgr)
    end
end

function AutoPopPlug:onUninstall()
    if not self.autoPopupMgr then return end
    for _, checkPoint in ipairs(self.registeredCheckPoints or {}) do
        self.autoPopupMgr:unregisterPopup(checkPoint)
    end
    self.registeredCheckPoints = {}
    self._registered = false
end

function AutoPopPlug:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
    self:_registerHostPopups()
end

function AutoPopPlug:getAutoPopupMgr()
    return self.autoPopupMgr
end

function AutoPopPlug:registerPopup(config)
    if not self.autoPopupMgr or not config then return end
    local checkPoint = self.autoPopupMgr:registerPopup(config)
    table.insert(self.registeredCheckPoints, checkPoint)
end

function AutoPopPlug:registerPopups(configs)
    if not configs then return end
    for _, config in ipairs(configs) do
        self:registerPopup(config)
    end
end

function AutoPopPlug:_registerHostPopups()
    if self._registered or not self.autoPopupMgr then return end
    if not self:hasHostMethod("_getAutoPopConfigList") then return end

    local configs = self:callHost("_getAutoPopConfigList")
    self:registerPopups(configs)
    self._registered = true
end

return AutoPopPlug
