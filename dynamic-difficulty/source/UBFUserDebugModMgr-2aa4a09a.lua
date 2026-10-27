local UBFUserDebugModMgr = class2("UBFUserDebugModMgr", UBFGameModManager)
UBFGameModManagerOrganizer:register(UBFModSourceIdEnum.kUserDebug, UBFUserDebugModMgr)

local STEP_PAD_BOARD_VIEW_NAME = "board"

function UBFUserDebugModMgr:onViewStaticInit()
    require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.UserDebug.UBFUserDebugModDeclares"
    require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.UserDebug.UBFUserDebugInfo"
    require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.UserDebug.gameplay.UBFUserDebugWidget"
end

function UBFUserDebugModMgr:isWillingEnabled(runtime, sourceId)
    if _G.AutoPlayEnv then return false end

    if not self:_isAdjustDebugInfoEnabled() then return false end
    return true
end

function UBFUserDebugModMgr:checkModIsEnabled(runtime)
    return true
end

function UBFUserDebugModMgr:createModData(runtime)
    local sourceId = runtime.sourceId
    local builder = UBFPlayModBuilder:create()
    --设置modEnv数据，依据自身需求设置，可缺省
    builder:setModSourceENV(sourceId, {})
    return builder:toCreateDatas()
end

function UBFUserDebugModMgr:_isAdjustDebugInfoEnabled()
    if UBFUserDebugModMgr.__adjustDebugInfoEnabled == nil then
        local testInfo
        testInfo = _G.amfBean("AccountManager"):getTestInfo()

        if testInfo then
            local enabled = false
            local pars = string.split(testInfo, ";")
            for k, v in ipairs(pars) do
                if v == "adjustDebugInfo" then
                    enabled = true
                    break
                end
            end
            UBFUserDebugModMgr.__adjustDebugInfoEnabled = enabled
        end
    end

    return UBFUserDebugModMgr.__adjustDebugInfoEnabled
end

function UBFUserDebugModMgr:_registerNodeClickListener()
    if UBFUserDebugModMgr.__isNodeClickListenerRegistered then return end

    local uiMgr = UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER)
    uiMgr:registerUiEventListener(UBFUiEventType.NODE_CLICK, UBFUserDebugModMgr)
    UBFUserDebugModMgr.__isNodeClickListenerRegistered = true
end

function UBFUserDebugModMgr:_unregisterNodeClickListener()
    if not UBFUserDebugModMgr.__isNodeClickListenerRegistered then return end

    local uiMgr = UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER)
    uiMgr:unregisterUiEventListener(UBFUiEventType.NODE_CLICK, UBFUserDebugModMgr)
    UBFUserDebugModMgr.__isNodeClickListenerRegistered = nil
end

-- function UBFUserDebugModMgr:onPrepareGameplayUi(event)
--     local eventData = event:getOrigin()
--     local createDelegate = eventData.createDelegate
--     UBFLogE("UBFUserDebugModMgr:onPrepareGameplayUi ", createDelegate)
-- end

function UBFUserDebugModMgr:onAfterBuildView(event)
    -- UBFLogD(25, "UBFUserDebugModMgr:onAfterBuildView ")
    if not self:_isAdjustDebugInfoEnabled() then return end

    local uiMgr = UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER)

    local itemsData = self:_getUserDebugInfo()

    local opParams = {
        nodeId = UBFUserDebugNodeId.WIDGET,
        uiData = {
            viewLogicConfig = {
                defaultInitParams = {
                    global = {
                        levelInfo = {
                            difficultyFlag = LevelDiffcultFlag.kExceedinglyDifficult,
                        },
                    },
                },
            },
            nodeConfig = {
                data = {
                    [UBFUserDebugNodeId.WIDGET] = {
                        logicId = UBFUserDebugLogicId.WIDGET,
                        parentParams = {
                            type = "GameplayNode",
                            nodeParams = {
                                layerKey = UBFGameplayLayerKey.DEBUG,
                            },
                        },
                        itemsData = itemsData,
                    },
                },
            },
        }
    }

    -- opParams.notifyGameSceneMods = true
    -- opParams.modEventNames = "PrepareUserDebugWidget"

    self:_registerNodeClickListener()
    uiMgr:exeOp(UBFUiOpType.CREATE_UI, opParams):next(function()
        self:_tryUpdateAdjustDebugInfo()
    end)
end

function UBFUserDebugModMgr:onNodeClick(eventData)
    if not eventData or eventData.blocked then return end
    if eventData.nodeId ~= UBFGameplayStepPadNodeId.ITEM then return end
    if eventData.viewName ~= STEP_PAD_BOARD_VIEW_NAME then return end

    local uiMgr = UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER)
    uiMgr:callNodeIfExists(UBFUserDebugNodeId.WIDGET, "expand")
end

function UBFUserDebugModMgr:dispose()
    self:_unregisterNodeClickListener()
end

function UBFUserDebugModMgr:onStartLevelProcessFinish(event)
    if not self:_isAdjustDebugInfoEnabled() then return end

    self:_tryUpdateAdjustDebugInfo()
end

function UBFUserDebugModMgr:onBoardStateChange(event)
    if not self:_isAdjustDebugInfoEnabled() then return end

    local currState = event:getCurrState()
    -- UBFLogD(25, "UBFUserDebugModMgr:onBoardStateChange "..tostring(event:getOldState()).." => "..tostring(currState))
    if currState ~= UBFConst.BoardSMKey.kWating then return end

    self:_tryUpdateAdjustDebugInfo()
end

function UBFUserDebugModMgr:_getFuuuSwitchStr()
    if UBFUserDebugModMgr.__fuuuSwitchStr ~= nil then
        return UBFUserDebugModMgr.__fuuuSwitchStr
    end

    local UBFuuuSelectAdjust = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuSelectAdjust")
    local maintenanceId, maintenanceName, _ = UBFuuuSelectAdjust:getSwitchInfo()
    UBFLogD(25, "UBFUserDebugModMgr:_getFuuuSwitchStr maintenanceId", maintenanceId, "maintenanceName", maintenanceName)

    local fuuuSwitchInfoStr
    -- if switchInfo and switchInfo.modGroup then
    --     local k, v = next(switchInfo.modGroup)
    --     if v == true then
    --         fuuuSwitchInfoStr = string.format("%s-%s", tostring(maintenanceId), tostring(k))
    --     end
    -- end

    -- UBFLogD(25, MaintenanceManager:getInstance():getMaintenanceByKey(maintenanceName))
    if maintenanceName then
        local uid
        uid = _G.amfBean("UserManager"):getUid() or "12345"

        local maintenanceMgr = MaintenanceManager:getInstance()

        local moduleKeySet = {}
        local range = maintenanceMgr:getGroupChildRangeMap(maintenanceName)
        if range then
            for _, v in ipairs(range) do
                for _, moduleKey in ipairs(v.modules) do
                    moduleKeySet[moduleKey] = true
                end
            end
        end
        local moduleKeys = table.keys(moduleKeySet)

        local enabledModuleKeys = {}
        for _, moduleKey in ipairs(moduleKeys) do
            if maintenanceMgr:isEnabledInGroup(maintenanceName, moduleKey, uid) then
                table.insert(enabledModuleKeys, moduleKey)
            end
        end
        local strModuleKeys = table.concat(enabledModuleKeys, " ")
        fuuuSwitchInfoStr = string.format("%s-%s", tostring(maintenanceId), strModuleKeys)
    end

    if fuuuSwitchInfoStr == nil then
        if EnvUtil:isMiniGame() then
            fuuuSwitchInfoStr = "1322-ubfuuu2025_mini_V4"
        else
            fuuuSwitchInfoStr = "1321-ubfuuu2025_app_V7"
        end
    end

    UBFUserDebugModMgr.__fuuuSwitchStr = fuuuSwitchInfoStr
    return fuuuSwitchInfoStr
end

function UBFUserDebugModMgr:_getUserDebugInfo()
    local infos = UBFUserDebugInfo:create()

    infos:addGroup("userTag", "用户标签")
    infos:addGroup("levelGroup", "分组信息")
    infos:addGroup("diffFix", "调节策略")
    infos:addGroup("details", "详细信息")

    local sceneMgr = UBFGameSceneManager:getInstance()
    if not sceneMgr then return {} end

    local levelInfo = sceneMgr:getLevelInfo()
    local notifyData = {
        levelId = levelInfo.levelId,
        levelScene = levelInfo.levelScene,
        infos = infos:getProxy(),
    }

    infos:addInfo("userTag", "activityIndex", "", "活跃档位", 1)
    infos:addInfo("userTag", "paymentIndex", "", "付费档位", 2)
    infos:addInfo("userTag", "playerAbility", "", "闯关能力档位", 3)
    -- 当前连胜次数
    local topWins
    topWins = _G.amfBean("LevelAreaManager"):getTopLevelWinCount()
    infos:addInfo("userTag", "topWins", topWins, "当前连胜次数", 4)

    -- 关卡分组
    local levelGroup = UBFPlaySwitch:getLevelGroup(levelInfo.levelId, levelInfo.levelScene)
    infos:addInfo("levelGroup", "levelGroup", levelGroup, "关卡分组", 1)
    local fuuuSwitch = self:_getFuuuSwitchStr()
    infos:addInfo("levelGroup", "fuuuSwitch", fuuuSwitch, "调节实验分组", 4)

    infos:addInfo("diffFix", "desiredDiffAvg", "", "预期难度", 1)
    infos:addInfo("diffFix", "diffIndex1", "", "查表难度指数", 2)
    infos:addInfo("diffFix", "diffIndex2", "", "闯关能力修正",3 )
    infos:addInfo("diffFix", "diffIndex", "", "最终难度指数", 4)
    infos:addInfo("diffFix", "desiredDiffAvgFix1", "", "难度指数修正后生效难度", 5)
    infos:addInfo("diffFix", "desiredDiffAvgFix2", "", "活动修正后生效难度", 7)
    infos:addInfo("diffFix", "desiredDiffAvgFix", "", "保底修正后生效难度", 8)
    infos:addInfo("diffFix", "diffFix1", "", "调节强度", 9)
    infos:addInfo("diffFix", "diffFix", "", "活动修正后的调节强度", 10)
    infos:addInfo("diffFix", "originDiffMove", "", "原始步数差", 11)
    infos:addInfo("diffFix", "fixedDiffMove1", "", "步数道具修正步数差", 12)
    infos:addInfo("diffFix", "diffMove", "", "最终修正步数差", 13)
    infos:addInfo("diffFix", "adjustStepCurrRate", "", "最终期望差值百分比", 14)
    infos:addInfo("diffFix", "currDs", "", "当前步实际调节强度", 15)

    infos:addInfo("details", "loginDayCount7", "", "过去7天登录天数", 1)
    infos:addInfo("details", "playCount3", "", "过去3天闯关次数", 2)
    infos:addInfo("details", "playCount7", "", "过去7天闯关次数", 3)
    infos:addInfo("details", "playCount30", "", "过去30天闯关次数", 4)
    infos:addInfo("details", "todayPassLevelCount", "", "当天过关次数", 5)
    infos:addInfo("details", "paymentIndexCount", "", "最终生效道具消耗Gold", 6)
    infos:addInfo("details", "v250801CashValue", "", "近30区域首过消耗Gold", 7)
    infos:addInfo("details", "v250801FarmCashValue", "", "近30区域刷星消耗Gold", 8)

    local event = UBFSceneModEventMap[UBFGameModEventEnum.GET_USER_DEBUG_INFO]:create(notifyData)
    sceneMgr:callGameModule(UBFGameLogics.kGameMod, "notifyEvent", event)

    local itemsData = infos:getOrderedList()
    return itemsData
end

function UBFUserDebugModMgr:_tryUpdateAdjustDebugInfo()
    local uiMgr =  UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER)
    if not uiMgr:existNode(UBFUserDebugNodeId.WIDGET) then UBFLogE("No UBFUserDebugNode") return end

    local sceneMgr = UBFGameSceneManager:getInstance()
    if not sceneMgr then UBFLogE("No UBFGameSceneManager") return end

    local msgLogic = sceneMgr:getMessageLogic()
    if not msgLogic then UBFLogE("No msgLogic") return end

    local promise = msgLogic:sendDataRequire(UBFGameRequireDataKey.kAdjustDebugInfo)
    promise:next(function(data)
        -- UBFLogD(25, "AdjustDebugInfo from Logic", data)
        local isDataValid, errMsg = self:_checkAdjustDebugInfoData(data)
        if not isDataValid then
            UBFLogE("UBFUserDebugModMgr AdjustDebugInfo data invalid", errMsg, data)
        end
        self:_doUpdateAdjustDebugInfo(data, errMsg)
    end)
end

function UBFUserDebugModMgr:_checkAdjustDebugInfoData(data)
    if type(data) ~= "table" then
        return false, "response is not table: "..tostring(data)
    end
    if data.err then
        return false, "response has err: "..tostring(data.err)
    end
    return true
end

function UBFUserDebugModMgr:_doUpdateAdjustDebugInfo(data, errMsg)
    data = type(data) == "table" and data or {}
    local adjustData = data.adjustData or {}
    local ubfuuCheckResult = adjustData.ubfuuCheckResult or {}
    local calculateDiffIndexResult = ubfuuCheckResult.calculateDiffIndexResult or {}
    local adjustStepData = data.adjustStepData or {}

    local updateItemsData = {}
    local function addInfo(groupKey, key, value, style)
        updateItemsData[#updateItemsData + 1] = {
            groupKey = groupKey,
            key = key,
            value = value,
            style = style,
        }
    end

    local function addDeltaInfo(groupKey, key, deltaVal, valFormatter)
        local str
        local style

        if tonumber(deltaVal) then
            deltaVal = tonumber(deltaVal)
            style = {}
            if valFormatter then
                str = string.format(valFormatter, math.abs(deltaVal))
                if tonumber(str) then
                    str = tostring(tonumber(str))
                end
            else
                str = tostring(math.abs(deltaVal))
            end
            if deltaVal > 0 then
                str = "差"..str
                style.fontColor = "FF5555"
            else
                str = "超"..str
                style.fontColor = "6FCF97"
            end
        else
            str = tostring(deltaVal)
        end
        addInfo(groupKey, key, str, style)
    end

    addInfo("userTag", "activityIndex", calculateDiffIndexResult.activityIndex)
    addInfo("userTag", "paymentIndex", calculateDiffIndexResult.paymentIndex)
    addInfo("userTag", "playerAbility", calculateDiffIndexResult.playerAbility)

    addInfo("diffFix", "desiredDiffAvg", ubfuuCheckResult.desiredDiffAvg)
    addInfo("diffFix", "diffIndex1", calculateDiffIndexResult.diffIndex1)
    addInfo("diffFix", "diffIndex2", calculateDiffIndexResult.diffIndex2)
    addInfo("diffFix", "diffIndex", calculateDiffIndexResult.diffIndex)
    addInfo("diffFix", "desiredDiffAvgFix1", ubfuuCheckResult.desiredDiffAvgFix1)
    addInfo("diffFix", "desiredDiffAvgFix2", ubfuuCheckResult.desiredDiffAvgFix2)
    addInfo("diffFix", "desiredDiffAvgFix", ubfuuCheckResult.desiredDiffAvgFix)
    addInfo("diffFix", "diffFix1", ubfuuCheckResult.diffFix1)
    addInfo("diffFix", "diffFix", ubfuuCheckResult.diffFix)
    addDeltaInfo("diffFix", "originDiffMove", adjustStepData.originDiffMove, "%.2f")
    addDeltaInfo("diffFix", "fixedDiffMove1", adjustStepData.fixedDiffMove1, "%.2f")
    addDeltaInfo("diffFix", "diffMove", adjustStepData.diffMove, "%.2f")
    addDeltaInfo("diffFix", "adjustStepCurrRate", adjustStepData.currRate, "%d%%")
    addInfo("diffFix", "currDs", adjustStepData.currDs)

    addInfo("details", "loginDayCount7", calculateDiffIndexResult.loginDayCount7)
    addInfo("details", "playCount3", calculateDiffIndexResult.playCount3)
    addInfo("details", "playCount7", calculateDiffIndexResult.playCount7)
    addInfo("details", "playCount30", calculateDiffIndexResult.playCount30)
    addInfo("details", "todayPassLevelCount", calculateDiffIndexResult.todayPassLevelCount)
    addInfo("details", "paymentIndexCount", calculateDiffIndexResult.paymentIndexCount)
    addInfo("details", "v250801CashValue", calculateDiffIndexResult.v250801CashValue)
    addInfo("details", "v250801FarmCashValue", calculateDiffIndexResult.v250801FarmCashValue)

    local uiMgr =  UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER)
    local opParams = {
        nodeId = UBFUserDebugNodeId.WIDGET,
        uiData = {
            nodeConfig = {
                data = {
                    [UBFUserDebugNodeId.WIDGET] = {
                        updateItemsData = updateItemsData,
                        expandErrorMsg = errMsg and ("调节调试信息获取失败："..tostring(errMsg)) or NIL,
                    },
                },
            },
        }
    }
    uiMgr:exeOp(UBFUiOpType.UPDATE_UI, opParams)

end

return UBFUserDebugModMgr:staticInit()
