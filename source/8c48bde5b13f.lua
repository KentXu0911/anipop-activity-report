local AbstractPlug = require "amf.script.pattern.plug.AbstractPlug"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"

local ActPlug = class("ActPlug", AbstractPlug)

function ActPlug:onInstall()
    local const = self.hostObj:getConst() or {}
    self.actId = const.actId or const.ACT_ID or const.actKey
    self.actSource = const.actSource
    self.model = self.hostObj:getModel()

    -- 非必须
    self.actName = const.actName

    if EnvUtil:isDevelopMode() then
        self:registerClearData()
    end
end

function ActPlug:shouldShowInLevelCard(hasParticipated)
    if not _G.amfBean("InLevelBridgeManager"):checkBottomSwitchON3() then
        return true
    end
    if hasParticipated then
        return true
    end

    return _G.amfBean("ActivityParticipationMgr"):shouldShowActivityCardByTag(self.actId)
end

function ActPlug:getActivityMgr()
    if not self.activityMgr then
        self.activityMgr = _G.amfBean("ActivityMgr")
    end
    return self.activityMgr
end

function ActPlug:getIconManager()
    if not self.iconManager then
        self.iconManager = _G.amfBean("IconManager")
    end
    return self.iconManager
end

function ActPlug:onUninstall()
    ActivityEventCenter:unregister(ActivityEvent.ACT_DATA_DELETE, self.onClearData)
end

function ActPlug:getActInfo(actId)
    return self:getActivityMgr():getActInfo(actId or self.actId)
end

function ActPlug:getActInfoExtraData(actId)
    local actInfo = self:getActInfo(actId)
    if not actInfo then
        return nil
    end
    if not actInfo.extra then
        return nil
    end
    local data =  table.deserialize(actInfo.extra)
    if not data then
        return nil
    end
    return data
end

function ActPlug:getActIcon(actId)
    return self:getIconManager():getIconByIconKey(tostring(actId or self.actId))
end

function ActPlug:getActName()
    return self.actName
end

-- 完整版，可以直接调用
function ActPlug:setActInfo(actInfo)
    ActivityEventCenter:dispatch(ActivityEvent.SET_ACT_INFO, actInfo)
end

-- 简化版，内部调用，理论上应该没啥理由单独用这个
function ActPlug:_setIconInfo(hasReward, msgNum, fromLocal)
    local actInfo = self:getActInfo()
    if not actInfo then
        return
    end
    actInfo.reward = hasReward
    actInfo.msgNum = msgNum
    actInfo.fromLocal = fromLocal
    ActivityEventCenter:dispatch(ActivityEvent.SET_ACT_INFO, actInfo)
end

function ActPlug:updateTipView()
    local hasReward, msgNum

    if self:hasHostMethod("hasReward") then
        hasReward = self:callHost("hasReward")
    end
    
    if self:hasHostMethod("getMsgNum") then
        msgNum = self:callHost("getMsgNum")
    end

    if hasReward == nil and msgNum == nil then
        return
    end

    self:_setIconInfo(hasReward, msgNum, true)
end

function ActPlug:openActivity(delegate)
    if not delegate then
        delegate = {}
    end

    if not self:getActivityMgr():isEnabled() then
        safeRunCall(delegate.failCallback)
        return
    end

    if delegate.userClick == nil then
        delegate.userClick = false
    end

    delegate.actId = delegate.actId or self.actId


    ActivityEventCenter:dispatch(ActivityEvent.OPEN_ACTIVITY, delegate)
end

-- 给测试按钮添加清数据
function ActPlug:registerClearData()
    local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"

    local function onClearData(evt)
        local data = evt:getData()
        if data.actId == self.actId then
            self.model:reset()
            CommonTip:showTip("活动" .. self.actId .. "本地数据已清除，最好重启一下游戏")
        end
    end

    self.onClearData = onClearData  
    ActivityEventCenter:register(ActivityEvent.ACT_DATA_DELETE, onClearData)
end

function ActPlug:registerActInfoUpdate(funcName)
    if self.hostObj and self.hostObj[funcName] then
        self.actInfoUpdateHandler = self.hostObj[funcName]
        ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE,
            self.hostObj[funcName], self.hostObj)
    end
end


return ActPlug
