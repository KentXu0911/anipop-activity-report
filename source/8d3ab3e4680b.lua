local TextUtil = require "amf.middleware.ui.util.TextUtil"
local baseConst = require("amf.middleware.activity.base.const.BaseFeatureManagerConst")
local baseEvent = require("amf.middleware.activity.base.const.BaseFeatureManagerEvent")
---@class BaseFeatureManager
local BaseFeatureManager = class("BaseFeatureManager")

function BaseFeatureManager:ctor()
    self.basePlugList = {}
end

function BaseFeatureManager:initialize()
    self:_initConst()
    self:_initModel()

    self:_initBasePlugList()
    self:_initNeedPlugs()

    self:_init()

    self:_checkAndNotifyPassDayOnInit()
end

function BaseFeatureManager:_initConst()
    local path = self:_getConstPath()
    if not path then
        return
    end

    self._const = require(path)
end

-- 获取常量
function BaseFeatureManager:getConst()
    return self._const
end

-- 获取基类的常量
function BaseFeatureManager:getBaseConst()
    return baseConst
end

-- 获取基类的常量
function BaseFeatureManager:getBaseEvent()
    return baseEvent
end

function BaseFeatureManager:_initModel()
    local path = self:_getModelPath()
    if not path then
        return
    end

    self._model = require(path):create()
end

---@return BaseFeatureModel
function BaseFeatureManager:getModel()
    return self._model
end

function BaseFeatureManager:_initBasePlugList()
    self.basePlugList = {{
        key = "Act"
    }, {
        key = "Notify"
    }}
end

function BaseFeatureManager:_initNeedPlugs()
    local plugs = self:_getAllPlugsConfigList()
    if not plugs or type(plugs) ~= "table" then
        return
    end

    -- 初始化模块
    for k, v in ipairs(plugs) do
        self:_initPlug(v.key, v.path)
    end
end

function BaseFeatureManager:_getAllPlugsConfigList()
    return table.union(self:_getBasePlugsConfigList(), self:_getExtraPlugsConfigList())
end

-- 基础必备插件，暂时没有，之后想到再加
function BaseFeatureManager:_getBasePlugsConfigList()
    return self.basePlugList
end

------------------------------------------- 打点 -------------------------------------------
function BaseFeatureManager:dcUserTrack(category, subCategory, extraData)
    local params = {
        game_type = "stage",
        category = category,
        sub_category = subCategory
    }

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end
    DcUtil:UserTrack(params)
end

function BaseFeatureManager:dcAct(category, subCategory, extraData)
    local params = {
        game_type = "stage",
        game_name = self:getConst().gameName,
        category = category,
        sub_category = subCategory
    }

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end

    DcUtil:activity(params)
end

------------------------------------------- 额外插件 -------------------------------------------
function BaseFeatureManager:_getPlugPath(key)
    return self:getBaseConst().plugPath .. key .. "Plug"
end

-- 如果要自己继承插件改的话自己传plugPath, 可以继承调用
-- 如果有自己的插件模块要添加也可以这么整，在自己的活动功能文件夹下整插件加上去。
function BaseFeatureManager:_initPlug(key, data)
    local plugPath
    if data and data.plugPath then
        plugPath = data.plugPath
    else
        plugPath = self:_getPlugPath(key)
    end

    local holdName = TextUtil:lowercaseFirstLetter(key) .. "Plug"

    self:_installPlug(key, data, plugPath):as(holdName)


    -- 插件函数调用
    self["call" .. key .. "Func"] = function(obj, funcName, ...)
        return obj:callPlug(key, funcName, ...)
    end
end

function BaseFeatureManager:_getPlugContainer()
    if not self.plugContainer then
        local PlugContainer = require "amf.script.pattern.plug.PlugContainer"
        self.plugContainer = PlugContainer:create(self, self:getBaseConst().plugPath)
    end
    return self.plugContainer
end

function BaseFeatureManager:_installPlug(plugType, installData, scriptPath)
    local plug = self:_getPlugContainer():install(plugType, installData, scriptPath)
    return {
        as = function(_, name)
            if name then
                if self[name] == plug then
                    self[name] = nil
                end
                self[name] = plug
            end
        end
    }
end

function BaseFeatureManager:_uninstallPlug(plugType)
    self:_getPlugContainer():uninstall(plugType)
end

function BaseFeatureManager:_getPlug(plugType)
    return self:_getPlugContainer():getPlug(plugType)
end

function BaseFeatureManager:callPlug(plugType, funcName, ...)
    return self:_getPlugContainer():call(plugType, funcName, ...)
end

function BaseFeatureManager:getBaseFileObject()
    return LocalDB:createFileObject("base_feature_manager")
end

-- 活动包支持状态由 ActivityNode 在启动阶段计算，避免业务模块重新加载包外 Config。
function BaseFeatureManager:isActivitySupported(actId)
    local activityMgr = _G.amfBean("ActivityMgr")
    actId = actId or (self:getConst() and (self:getConst().actId or self:getConst().ACT_ID))
    return actId ~= nil and activityMgr:isActReady(actId) == true
end
------------------------------------------- 业务 -------------------------------------------
-- 跨天刷新数据
function BaseFeatureManager:_checkAndNotifyPassDayOnInit()
    if not self.passDayRefreshData then return end

    local fileObj = self:getBaseFileObject()
    if not fileObj then return end

    local last_save_key = self:getClassName() .. "_lastSavedTime"
    local lastSavedTime = fileObj:getValue(last_save_key)
    local nowTime = tostring(TimeKit:getTodayStart())
    if lastSavedTime ~= nil and lastSavedTime ~= nowTime then
        self:passDayRefreshData()
    end
    fileObj:setValue(last_save_key, nowTime)
    fileObj:saveAsync(0.5)
end

function BaseFeatureManager:onActPassDay()
    self:_checkAndNotifyPassDayOnInit()
end

function BaseFeatureManager:addEventDispatcher(prefix)
    if self.notifyPlug then
        self.notifyPlug:addEventDispatcher(prefix)
    end
end


------------------------------------------- 需要overwrite的函数 -------------------------------------------
-- 获取常量路径
function BaseFeatureManager:_getConstPath()
end

-- 获取model路径
function BaseFeatureManager:_getModelPath()
end

-- 获取需要启动的额外功能列表
function BaseFeatureManager:_getExtraPlugsConfigList()
    return {}
    -- return {
    --     {key = "xxx", path = "xxx"} -- 如果有自己实现或继承的plug则传path，否则不用
    -- }
end

-- 如果有自己需要初始化的内容，覆写这个
function BaseFeatureManager:_init()
end

-- 功能是否可以启动
function BaseFeatureManager:isEnabled()
end

-- act可选实现
-- function BaseFeatureManager:hasReward()
-- end

-- act可选实现
-- function BaseFeatureManager:getMsgNum()
-- end

-- Rewards可选实现
-- 如果没有把道具注册进道具系统，可以用这个
-- function BaseFeatureManager:addActItem(rewards)
-- end

-- Scheduler可选实现
-- function BaseFeatureManager:updateByTime()
-- end

-- Scheduler可选实现
-- function BaseFeatureManager:updateOnce()
-- end

return BaseFeatureManager
