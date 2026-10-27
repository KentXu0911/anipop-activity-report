-- @Author: zhijian.li
-- @Date:   2021-05-26 16:49:28
-- @Last Modified by:   zhijian.li
-- @Last Modified time: 2021-12-30 18:09:27
local AutoPopupDebugLog = require "amf.middleware.autopop.AutoPopupDebugLog"
local APMetaConfigRef = class("APMetaConfigRef", AMFDataRef)

-- 成员变量声明
function APMetaConfigRef:__declare()
    self.metaId = 0
    self.actId = 0

    self.beginTime = 0
    self.endTime = 0

    self.actSource = nil
    self.actVersion = nil

    self.autoPopScene = nil

    self.autoPopPayType = nil
    self.autoPopActiveType = nil
    self.autoPopMinLevel = nil
    self.autoPopMaxLevel = nil
    self.autoPopMinStar = nil
    self.autoPopMaxStar = nil

    self.autoPopMinEnergy = nil
    self.autoPopUnlimitedEnergy = nil
    self.autoPopRelativePriority = nil
    self.groupSwitch = nil
    self.autoPopRule = nil
    -- R1和R2规则时，用于控制强弹次数
    self.autoPopRuleParam1 = nil
    -- 规则预留参数，暂时无用
    self.autoPopRuleParam2 = nil

    -- 字符串为活动config.lua里对应的函数名，用于自定义的强弹检测规则和弹出处理，需对应配置在act_auto_popup_config.xml里
    self.autoPopCustomizedCheck = nil
    self.autoPopCustomizedCreator = nil

    self.uniqueKey = nil

    self._isResLoaded = false

    self._popScene = nil
end

function APMetaConfigRef:updateConfigData(configData)
    self:setValue("metaId",configData.metaId)
    self:setValue("actId",configData.actId)

    self:setValue("beginTime",configData.beginTime)
    self:setValue("endTime",configData.endTime)

    self:setValue("autoPopScene",configData.autoPopScene)

    self:setValue("autoPopPayType",configData.autoPopPayType)
    self:setValue("autoPopActiveType",configData.autoPopActiveType)
    self:setValue("autoPopMinLevel",configData.autoPopMinLevel)
    self:setValue("autoPopMaxLevel",configData.autoPopMaxLevel)
    self:setValue("autoPopMinStar",configData.autoPopMinStar)
    self:setValue("autoPopMaxStar",configData.autoPopMaxStar)

    self:setValue("autoPopMinEnergy",configData.autoPopMinEnergy)
    self:setValue("autoPopUnlimitedEnergy",configData.autoPopUnlimitedEnergy)
    self:setValue("autoPopRelativePriority",configData.autoPopRelativePriority)
    self:setValue("groupSwitch",configData.groupSwitch)
    self:setValue("autoPopRule",configData.autoPopRule)
    -- R1和R2规则时，用于控制强弹次数
    self:setValue("autoPopRuleParam1",configData.autoPopRuleParam1)
    -- 规则预留参数，暂时无用
    self:setValue("autoPopRuleParam2",configData.autoPopRuleParam2)

    -- 字符串为活动config.lua里对应的函数名，用于自定义的强弹检测规则和弹出处理，需对应配置在act_auto_popup_config.xml里
    self:setValue("autoPopCustomizedCheck",configData.autoPopCustomizedCheck)
    self:setValue("autoPopCustomizedCreator",configData.autoPopCustomizedCreator)
end

function APMetaConfigRef:setIsResLoaded(flag)
    self:setValue("_isResLoaded",flag)
end

function APMetaConfigRef:getIsResLoaded()
    return EnvUtil:isWindows() or EnvUtil:isUnityEditor() or EnvUtil:isMiniGameDev() or self:getValue("_isResLoaded")
end

function APMetaConfigRef:setActSource(source)
    self:setValue("actSource", source)
end

function APMetaConfigRef:getActSource()
    return self:getValue("actSource")
end

function APMetaConfigRef:getMetaId()
    return self:getValue("metaId")
end

function APMetaConfigRef:getActId()
    return self:getValue("actId")
end

function APMetaConfigRef:getPopScene()
    local _popScene = self:getValue("_popScene")
    if not _popScene then
        local tmp = {}
        local autoPopScene = self:getValue("autoPopScene")
        if autoPopScene and type(autoPopScene) == "table" then
            for i, v in ipairs(self.autoPopScene) do
                local stageIndex = tostring(v)
                if AutoPopupConst.PopStageKeyMapping[stageIndex] then
                    table.insert(tmp, v)
                end
            end
        end
        if table.isEmpty(tmp) then
            tmp = {AutoPopupConst.PopStageId.kEnterFromOutside}
        end
        _popScene = tmp
        self:setValue("_popScene", tmp)
    end
    return _popScene
end

-- 配置了场景3的强弹，会忽略同时配置的其它场景
-- 场景3的强弹，必须配置为自定义强弹
function APMetaConfigRef:isStage3CustomizedPopup()
    if not self:getCustomizedCreator() then
        return
    end
    for i, v in ipairs(self:getPopScene()) do
        if v == AutoPopupConst.PopStageId.STAGE_THREE then
            return true
        end
    end
    return false
end

-- 配置场景4自定义强弹时，场景字段只能填4，如果多配了2，会忽略自定义强弹，变成弹活动主面板
function APMetaConfigRef:isStage4CustomizedPopup()
    if not self:getCustomizedCreator() then
        return
    end
    local popScene = self:getPopScene()
    if #popScene ~= 1 then
        AutoPopupDebugLog:log("Wrong config, popScene field should only contain 4. " .. self:getMetaId())
        return
    end
    if popScene[1] ~= AutoPopupConst.PopStageId.STAGE_FOUR then
        AutoPopupDebugLog:log("Wrong config, popScene field should only contain 4. " .. self:getMetaId() .. popScene[1])
        return
    end

    return true
end

function APMetaConfigRef:getPopRelativePriority()
    local autoPopRelativePriority = self:getValue("autoPopRelativePriority")
    local priority = 10100 - (autoPopRelativePriority or 0)

    return priority
end

function APMetaConfigRef:getPopRule()
    return self:getValue("autoPopRule")
end

function APMetaConfigRef:getPopRuleParam1()
    return self:getValue("autoPopRuleParam1")
end

function APMetaConfigRef:getPopRuleParam2()
    return self:getValue("autoPopRuleParam2")
end

function APMetaConfigRef:getCacheUniqueKey()
    local uniqueKey = self:getValue("uniqueKey")
    if not uniqueKey then
        uniqueKey = self:createUniqueKey()
        self:setValue("uniqueKey", uniqueKey)
    end
    return uniqueKey
end

function APMetaConfigRef:createUniqueKey()
    local actId = self:getActId()
    local metaId = self:getMetaId()
    local autoPopRule = self:getPopRule()
    local uniqueKey
    if autoPopRule == AutoPopupConst.MetaPopupRules.EVERY_DAY then
        local todayStartTime = TimeKit:getTodayStart()
        uniqueKey = string.format("%s_%s_%s_%s", autoPopRule, actId, metaId, todayStartTime)
    elseif autoPopRule == AutoPopupConst.MetaPopupRules.A_LIFE_TIME then
        local endTime = self:getValue("endTime")
        uniqueKey = string.format("%s_%s_%s_%s", autoPopRule, actId, metaId, endTime)
    elseif autoPopRule == AutoPopupConst.MetaPopupRules.EVERY_TIME then
        uniqueKey = string.format("%s_%s_%s", autoPopRule, actId, metaId)
    else
        assert(false, "invalid auto popup rule" .. autoPopRule)
    end
    return uniqueKey
end

function APMetaConfigRef:isRuleEffective()
    local uniqueKey = self:getCacheUniqueKey()
    if not uniqueKey then
        return false
    end
    local autoPopRule = self:getPopRule()
    if autoPopRule == AutoPopupConst.MetaPopupRules.EVERY_DAY then
        local curPopNum = _G.amfBean("AutoPopupMgr"):getCheckPointPopNum(uniqueKey)
        local limitNum = self:getPopRuleParam1() and tonumber(self:getPopRuleParam1()) or 1
        if curPopNum < limitNum then
            return true
        else
            return false
        end
    elseif autoPopRule == AutoPopupConst.MetaPopupRules.A_LIFE_TIME then
        local curPopNum = _G.amfBean("AutoPopupMgr"):getPermanentShowNum(uniqueKey)
        local limitNum = self:getPopRuleParam1() and tonumber(self:getPopRuleParam1()) or 1
        if curPopNum < limitNum then
            return true
        else
            return false
        end
    elseif autoPopRule == AutoPopupConst.MetaPopupRules.EVERY_TIME then
        return true
    else
        assert(false, "invalid auto popup rule" .. autoPopRule)
        return false
    end
end

function APMetaConfigRef:needSyncPopupNum()
    local uniqueKey = self:getCacheUniqueKey()
    if not uniqueKey then
        return false
    end
    local autoPopRule = self:getPopRule()
    return autoPopRule == AutoPopupConst.MetaPopupRules.EVERY_DAY or autoPopRule ==
               AutoPopupConst.MetaPopupRules.A_LIFE_TIME
end

-- 调用时机：强弹后，或手动点击活动后
function APMetaConfigRef:syncPopupNum()
    local uniqueKey = self:getCacheUniqueKey()
    if not uniqueKey then
        return false
    end
    local autoPopRule = self:getPopRule()
    if autoPopRule == AutoPopupConst.MetaPopupRules.EVERY_DAY then
        _G.amfBean("AutoPopupMgr"):sendDailyData(uniqueKey)
    elseif autoPopRule == AutoPopupConst.MetaPopupRules.A_LIFE_TIME then
        _G.amfBean("AutoPopupMgr"):sendPermanentData(uniqueKey)
    elseif autoPopRule == AutoPopupConst.MetaPopupRules.EVERY_TIME then
        -- do nothing
    else
        assert(false, "invalid auto popup rule" .. autoPopRule)
        return false
    end
end

function APMetaConfigRef:shouldRemoveAfterPop()
    local uniqueKey = self:getCacheUniqueKey()
    if not uniqueKey then
        return true
    end
    local autoPopRule = self:getPopRule()
    if autoPopRule == AutoPopupConst.MetaPopupRules.EVERY_DAY then
        local curPopNum = _G.amfBean("AutoPopupMgr"):getCheckPointPopNum(uniqueKey)
        local limitNum = self:getPopRuleParam1() and tonumber(self:getPopRuleParam1()) or 1
        if curPopNum >= limitNum then
            return true
        else
            return false
        end
    elseif autoPopRule == AutoPopupConst.MetaPopupRules.A_LIFE_TIME then
        local curPopNum = _G.amfBean("AutoPopupMgr"):getPermanentShowNum(uniqueKey)
        local limitNum = self:getPopRuleParam1() and tonumber(self:getPopRuleParam1()) or 1
        if curPopNum >= limitNum then
            return true
        else
            return false
        end
    else
        return false
    end
end

function APMetaConfigRef:isTimeEffective()
    local beginTime = self:getValue("beginTime")
    local endTime = self:getValue("endTime")
    if not beginTime or not endTime then
        return false
    end
    local now = TimeKit:timeInSec()
    if now < beginTime then
        return false
    end
    if now > endTime then
        return false
    end
    return true
end

-- 活动剩余有效期是否足够（暂定60s）
function APMetaConfigRef:isRemainTimeEnough()
    local endTime = self:getValue("endTime")
    return (endTime - TimeKit:timeInSec()) > 60
end

function APMetaConfigRef:isPayTypeEffective()
    local autoPopPayType = self:getValue("autoPopPayType")
    if autoPopPayType then
        local userPayType = self:getPaymentTagMapping()
        if table.includes(autoPopPayType, userPayType) then
            return true
        else
            AutoPopupDebugLog:log(
                "APMetaConfigRef:isPayTypeEffective false " .. self:getActId() .. "_" .. userPayType .. "_" ..
                    table.tostring(autoPopPayType))
            return false
        end
    end

    return true
end

function APMetaConfigRef:getPaymentTagMapping()
    local paymentTag = UserTagManager:getUserPaymentTag()
    return lua_switch(paymentTag) {
        [UserPaymentTag.kNone] = 0,
        [UserPaymentTag.kLow] = 1,
        [UserPaymentTag.kMidLow] = 2,
        [UserPaymentTag.kMidHigh] = 3,
        [UserPaymentTag.kHigh] = 4,
        default = function()
            return -1
        end
    }
end

function APMetaConfigRef:isActiveTypeEffective()
    local autoPopActiveType = self:getValue("autoPopActiveType")
    if autoPopActiveType then
        local userActiveType = self:getActiveTagMapping()
        if table.includes(autoPopActiveType, userActiveType) then
            return true
        else
            AutoPopupDebugLog:log("APMetaConfigRef:isActiveTypeEffective false " .. self:getActId() .. "_" ..
                                      userActiveType .. "_" .. table.tostring(autoPopActiveType))
            return false
        end
    end

    return true
end

function APMetaConfigRef:getActiveTagMapping()
    local livenessTagValueMap = UserTagValueMap[UserTagNameKeyFullMap.kBiLivenessTag]
    local livenessTag = UserTagManager:getUserTagBySeries(UserTagNameKeyFullMap.kBiLivenessTag)
    return lua_switch(livenessTag) {
        [livenessTagValueMap.kNewUser] = 1,
        [livenessTagValueMap.kReturnUser] = 2,
        [livenessTagValueMap.kLowUser] = 3,
        [livenessTagValueMap.kMiddleLowUser] = 4,
        [livenessTagValueMap.kMiddleUser] = 5,
        [livenessTagValueMap.kMiddleHighUser] = 6,
        [livenessTagValueMap.kHighUser] = 7,
        default = function()
            return 0
        end
    }
end

-- 支持多开关配置"switch1|ON1;switch1|ON2" or "switch1|ON;switch2|ON1;switch2|ON2"
function APMetaConfigRef:isGroupSwitchEffective()
    local groupSwitch = self:getValue("groupSwitch")
    if groupSwitch then
        local switches = splite(groupSwitch, ";")
        if #switches == 0 then
            return true
        end
        for _, singleSwitch in ipairs(switches) do
            local groupSwitchTb = splite(singleSwitch, "|")
            local switchName = groupSwitchTb[1]
            local switchGroup = groupSwitchTb[2]
            if not switchName or not switchGroup then
                return true
            end
            local isEnabled, _, src = MaintenanceManager.getInstance():isEnabledInGroup(switchName, switchGroup)
            if not isEnabled then
                -- 开关不存在或者配错时，视为开关生效
                isEnabled = src == 5
            end
            if isEnabled then
                return true
            end
        end
    else
        return true
    end
    return false
end

function APMetaConfigRef:isLevelEffective()
    local autoPopMinLevel = self:getValue("autoPopMinLevel")
    local autoPopMaxLevel = self:getValue("autoPopMaxLevel")
    if autoPopMinLevel and autoPopMaxLevel then
        if autoPopMinLevel == -1 and autoPopMaxLevel == -1 then
            local userState = _G.amfBean("UserStateManager"):getUserState()
            if userState == _G.UserStateConst.UserLevelState.TOP_LEVEL or userState ==
                _G.UserStateConst.UserLevelState.TOP_STAR then
                return true
            else
                AutoPopupDebugLog:log("APMetaConfigRef:isLevelEffective 1 false " .. self:getActId() .. "_" .. userState)
                return false
            end
        else
            local topLevel = _G.getTopLevelId()
            if topLevel >= autoPopMinLevel and topLevel <= autoPopMaxLevel then
                return true
            else
                AutoPopupDebugLog:log("APMetaConfigRef:isLevelEffective 2 false " .. self:getActId() .. "_" .. topLevel)
                return false
            end
        end
    end

    return true
end

function APMetaConfigRef:isStarEffective()
    local autoPopMinStar = self:getValue("autoPopMinStar")
    local autoPopMaxStar = self:getValue("autoPopMaxStar")
    if autoPopMinStar and autoPopMaxStar then
        if autoPopMinStar == -1 and autoPopMaxStar == -1 then
            local userState = _G.amfBean("UserStateManager"):getUserLevelState()
            if userState == _G.UserStateConst.UserLevelState.TOP_STAR then
                return true
            else
                AutoPopupDebugLog:log("APMetaConfigRef:isStarEffective 1 false " .. self:getActId() .. "_" .. userState)
                return false
            end
        else
            local userStarMain = _G.amfBean("UserManager"):getStar()
            local userStarHide = _G.amfBean("UserManager"):getHiddenStar()
            local userFullStar = userStarMain + userStarHide
            if userFullStar >= autoPopMinStar and userFullStar <= autoPopMaxStar then
                return true
            else
                AutoPopupDebugLog:log("APMetaConfigRef:isStarEffective 2 false " .. self:getActId() .. "_" ..
                                          userStarMain .. "_" .. userStarHide)
                return false
            end
        end
    end
    return true
end

function APMetaConfigRef:isMinEnergyEffective()
    local autoPopMinEnergy = self:getValue("autoPopMinEnergy")
    if autoPopMinEnergy then
        local curEnergy = _G.amfBean("UserManager"):getEnergy() or 30
        if curEnergy <= autoPopMinEnergy then
            return true
        else
            AutoPopupDebugLog:log(
                "APMetaConfigRef:isMinEnergyEffective false " .. self:getActId() .. "_" .. curEnergy .. "_" ..
                    autoPopMinEnergy)
            return false
        end
    end
    return true
end

function APMetaConfigRef:isUnlimitedEnergyEffective()
    local autoPopUnlimitedEnergy = self:getValue("autoPopUnlimitedEnergy")
    if autoPopUnlimitedEnergy == nil or autoPopUnlimitedEnergy == "" then
        return true
    end

    local energyState = _G.amfBean("UserEnergyManager"):getEnergyState()
    local isInfinite = energyState == _G.UserEnergyState.INFINITE
    local isEnabled = false
    if autoPopUnlimitedEnergy == "true" then
        isEnabled = isInfinite
    else
        isEnabled = not isInfinite
    end

    if not isEnabled then
        AutoPopupDebugLog:log("APMetaConfigRef:isUnlimitedEnergyEffective false " .. self:getActId() .. "_" ..
                                  energyState)
    end

    return isEnabled
end

--非自定义强弹
function APMetaConfigRef:isMetaPopConfig()
    local autoPopCustomizedCreator = self:getValue("autoPopCustomizedCreator")
    if autoPopCustomizedCreator == nil then
        return true
    end
end

function APMetaConfigRef:isCustomizedCheckFulfill(data)
    local autoPopCustomizedCheck = self:getValue("autoPopCustomizedCheck")
    if autoPopCustomizedCheck == nil then
        return true
    end
    if EnvUtil:isDevelopMode() then
        local ret = autoPopCustomizedCheck(data or {})
        return ret
    end
    local status, ret = pcall(autoPopCustomizedCheck, data or {})
    return status and ret
end

function APMetaConfigRef:getCustomizedCreator()
    return self:getValue("autoPopCustomizedCreator")
end

-- 检测并准备强弹数据
function APMetaConfigRef:checkAndGetPopData(data)
    local levelData = data.levelData
    local popupStage = data.popStage
    local isMetaPop = data.isMetaPop
    local popData

    --配置化强弹自定义不触发
    if isMetaPop and not self:isMetaPopConfig() then
        return
    end

    if not table.exist(self:getPopScene(), popupStage) then
        return
    end

    if isMetaPop and _G.amfBean("ActivityParticipationMgr")
        :shouldReduceConfiguredMainPanelAutoPopup(self:getActId()) then
        return
    end

    if self:isLevelEffective() and self:isStarEffective() and self:isMinEnergyEffective() and
        self:isUnlimitedEnergyEffective() and self:isCustomizedCheckFulfill(levelData) then
        local metaId = self:getMetaId()
        local actId = self:getActId()

        -- 主面板强弹
        local function setPopData(type)
            popData = {
                metaId = metaId,
                actId = actId,
                levelData = data,
                priority = self:getPopRelativePriority(),
                autoPopupConfig = self,
                type = type,
            }
        end

        if isMetaPop then
            --剩余时间足够触发
            if self:isRemainTimeEnough() then
                setPopData(ActivityConst.PopType.MAIN_PANEL)
            end
        else
            if popupStage == AutoPopupConst.PopStageId.STAGE_THREE and self:isStage3CustomizedPopup() then
                setPopData(ActivityConst.PopType.CUSTOMIZE)
            elseif popupStage == AutoPopupConst.PopStageId.STAGE_FOUR and self:isStage4CustomizedPopup() then
                setPopData(ActivityConst.PopType.CUSTOMIZE)
            end
        end
    end

    return popData
end

return APMetaConfigRef
