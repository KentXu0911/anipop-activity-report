-- 负责发现新活动和配置强弹
local IProcessor = require "amf.middleware.activity.processor.IProcessor"
local AutoPopupProcessor = class("AutoPopupProcessor").implement(IProcessor)
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local APMetaConfigRef = require "amf.middleware.activity.config.APMetaConfigRef"
local ActivityDebugLog = require "amf.middleware.activity.debug.ActivityDebugLog"

-- 创建
function AutoPopupProcessor:create(source, actId)
    local cls = self.new()
    cls:init(source, actId)
    return cls
end

function AutoPopupProcessor:init(source, actId)
    self._source = source
    self._actId = actId

    self._eventHandled = false

    self._autoPopupConfig = {}
end

--强弹结束
function AutoPopupProcessor:popupOverFunc(data)
    local metaId = data.metaId
    local actId = data.actId
    local popupConfig

    ActivityDebugLog:logAutoPop(metaId, actId, "强弹结束，申请取消")
    if metaId then
        popupConfig = self._autoPopupConfig[tostring(metaId)]
    elseif actId then
        for k, v in pairs(self._autoPopupConfig) do
            if tonumber(v:getActId()) == tonumber(actId) and not v:isStage3CustomizedPopup() and not v:isStage4CustomizedPopup() then
                popupConfig = v
                metaId = v:getMetaId()
                break
            end
        end
    end

    if popupConfig then
        local needSync = popupConfig:needSyncPopupNum()
        if needSync then
            popupConfig:syncPopupNum()
        end
        local shouldRemove = popupConfig:shouldRemoveAfterPop()
        ActivityDebugLog:logAutoPop(popupConfig:getMetaId(), popupConfig:getActId(), "强弹结束，实际取消"
            ,"需要同步到后端" .. tostring(needSync), "需要移除强弹" .. tostring(shouldRemove))
        if shouldRemove then
            self._autoPopupConfig[tostring(metaId)] = nil
        end
    end
end

function AutoPopupProcessor:process()
    if not self:getEventHandled() then
        self:handleConfigPopup()
        self:setEventHandled(true)
        if self._autoPopupConfig and next(self._autoPopupConfig) ~= nil then
            return true
        end
    end
end

function AutoPopupProcessor:setEventHandled(flag)
    self._eventHandled = flag
end

function AutoPopupProcessor:getEventHandled()
    return self._eventHandled
end

-- 配置强弹处理入口
function AutoPopupProcessor:handleConfigPopup()
    local config = require("activity/" .. self._source)
    -- 活动状态切换会重跑本函数（ActivityNode:handleAutoPopup），先清掉上一次的配置，
    -- 避免活动已 ignore / 无 AutoPopupMgr 时残留旧强弹配置。
    self:removeOldConfig()
    if self:ignoreAutoPop(config) then
        return
    end

    if not _G.amfBean("AutoPopupMgr") then
        return
    end

    self:addConfigToPopQueue(config, self._source)
end

function AutoPopupProcessor:removeOldConfig()
    self._autoPopupConfig = {}
end

function AutoPopupProcessor:addConfigToPopQueue(config, source)
    local _popupConfigs = self:genActAutoPopupConfig(config.autoPopConfigs, config)

    local function insertToTable(tbl, popupConfig)
        tbl[tostring(popupConfig:getMetaId())] = popupConfig
    end
    for _, popupConfig in ipairs(_popupConfigs) do
        popupConfig:setActSource(source)
        insertToTable(self._autoPopupConfig,popupConfig)
    end
end

function AutoPopupProcessor:genActAutoPopupConfig(autoPopConfigs, actConfig)
    local ret = {}
    for i, v in ipairs(autoPopConfigs) do
        local config = table.clone(v)
        config.autoPopCustomizedCheck = self:getFunctionFromActConfig(actConfig, config.autoPopCustomizedCheck)
        config.autoPopCustomizedCreator = self:getFunctionFromActConfig(actConfig, config.autoPopCustomizedCreator)
        local popupConfig = APMetaConfigRef:create()
        popupConfig:updateConfigData(config)
        if popupConfig:isTimeEffective() and popupConfig:isRuleEffective() and popupConfig:isPayTypeEffective() and
            popupConfig:isActiveTypeEffective() and popupConfig:isGroupSwitchEffective() then
            table.insert(ret, popupConfig)
        end
    end
    return ret
end

function AutoPopupProcessor:setIsResLoaded(loaded)
    for k, v in pairs(self._autoPopupConfig) do
        v:setIsResLoaded(loaded)
    end
end

function AutoPopupProcessor:getFunctionFromActConfig(actConfig, funcKey)
    funcKey = tostring(funcKey)
    if not funcKey then
        return
    end
    if funcKey == "" or funcKey == "nil" then
        return
    end
    if not actConfig[funcKey] then
        return
    end
    if type(actConfig[funcKey]) ~= "function" then
        return
    end

    return actConfig[funcKey]
end

function AutoPopupProcessor:getAutoPopupData(delegate)
    local ret = {}
    for k, v in pairs(self._autoPopupConfig) do
        local popData = v:checkAndGetPopData(delegate)
        table.insert(ret, popData)
    end

    return ret
end

function AutoPopupProcessor:checkHasAutoPopupByMetaId(metaId)
    for k, v in pairs(self._autoPopupConfig) do
        if v:getMetaId() == metaId then
            return true
        end
    end
    return false
end

function AutoPopupProcessor:ignoreAutoPop(config)
    if not config.autoPopConfigs then
        return true
    end
    return config.ignoreAutoPopup
end

function AutoPopupProcessor:dispose()
    self:removeOldConfig()
end

return AutoPopupProcessor
