UBFProcessModManager = class2("UBFProcessModManager", UBFBaseLogic)

local EDITOR_IGNORE_EVENT_NAMES

function UBFProcessModManager:build(createData)
    self.runtime = createData.runtime
    self.processType = self.runtime:getProcessType()
    self.modClazzMap = UBFGameModManagerOrganizer.modClazzMap
    self.willingModList = {}
    self.modOpenStatusMap = {}
    self.modContextData = {}
    self.modDataList = {}
end

-- 加载全部有处理意愿的mod
function UBFProcessModManager:loadAllWillingMod(defaultWillingList)
    for sourceId, modClazz in pairs(self.modClazzMap) do
        local isEnabled = defaultWillingList and defaultWillingList[sourceId]
        if not isEnabled then
            isEnabled = modClazz:isWillingEnabled(self.runtime, sourceId)
        end
        if isEnabled then
            table.insert(self.willingModList, sourceId)
            self.modContextData[sourceId] = {}
        end
    end

    -- 活动可在意愿检查时声明隔离策略，因此统一在检查结束后应用白名单。
    local willingModAllowList = self.runtime:getExtra("willingModAllowList")
    if type(willingModAllowList) == "table" then
        for index = #self.willingModList, 1, -1 do
            local sourceId = self.willingModList[index]
            if willingModAllowList[tostring(sourceId)] ~= true then
                table.remove(self.willingModList, index)
                self.modContextData[sourceId] = nil
            end
        end
    end
    table.sort(self.willingModList, function(a, b)
        local na = UBFModHelper:getModPriority(a)
        local nb = UBFModHelper:getModPriority(b)
        return na < nb
    end)
--
--
--
--
--
--
--
--

end

--发送事件
function UBFProcessModManager:_notify(eventName, data, protectedMode, onError)
    local noError = true
    -- todo
    --todo 临时写的，后面要改成正式的，写到这里的都是咱们自己的业务  ，是需要迁移的，不能删除的，也不属于关卡外
    --todo XXXXMigrator.lua这里面的，要不然是要删的，要不然是关卡外业务
    if self.runtime.migrator and not self.runtime:isPlayerStateSandbox() then
        local listener = self.runtime.migrator.modListener[eventName]
        if listener then
            if protectedMode then
                local ok = UBFHelper:callProtected(listener,
                    "[UBFProcessModManager] notify migrator "..tostring(eventName), self.runtime, data)
                noError = noError and ok
            else
                listener(self.runtime, data)
            end
        end
    end
    local ok = self:_notifyModEvent(eventName, data, protectedMode)
    noError = noError and ok
    if not noError and onError then
        UBFHelper:callProtected(onError, string.format("[UBFProcessModManager] notify %s call onError", eventName))
    end
end

-- 默认按保护模式进行事件派发
function UBFProcessModManager:notify(eventName, data, onError)
    return self:_notify(eventName, data, true, onError)
end

function UBFProcessModManager:notifyUnprotected(eventName, data)
    return self:_notify(eventName, data, false)
end

function UBFProcessModManager:isEditorIgnoredEvent(eventName)
    EDITOR_IGNORE_EVENT_NAMES = EDITOR_IGNORE_EVENT_NAMES or {
        UBFGameModEventEnum.PREPARE_SLP_BOTTOM,
        UBFGameModEventEnum.PREPARE_SLP_TOP,
        UBFGameModEventEnum.PREPARE_SLP_TAG,
        UBFGameModEventEnum.PREPARE_SLP_RIGHT_UPPER,
        UBFGameModEventEnum.PREPARE_SLP_LEFT_BOTTOM,
        UBFGameModEventEnum.PREPARE_SLP_SUBTITLE,
        UBFGameModEventEnum.PREPARE_SLP_RIGHT_BOTTOM,
        UBFGameModEventEnum.PREPARE_SLP_ENTER_ACTIONS,
        UBFGameModEventEnum.PREPARE_SLP_BOTTOM_CAROUSEL,
    }
    return table.indexOf(EDITOR_IGNORE_EVENT_NAMES, eventName) ~= nil
end

function UBFProcessModManager:_notifyModEvent(eventName, data, protectedMode)
    local noError = true
    if _G.editorMode then
        if self:isEditorIgnoredEvent(eventName) then
            return noError
        end
    end

    local getNotifyEventModDataList = UBFModHelper:getNotifyEventModDataList(self.willingModList, eventName)
    local event = UBFSceneModEventMap[eventName]:create(data)
    local oldSourceId = self.runtime.sourceId
    for k, v in ipairs(getNotifyEventModDataList) do
        if event:getBlock() then
           break
        end
        local isGroupBlock = v.groupId and event:getGroupBlock(v.groupId)
        if not isGroupBlock then
            self.runtime.sourceId = v.sourceId
            local strSourceId = tostring(v.sourceId)
            event:setCurrGroupId(v.groupId)
            event:setRuntime(self.runtime)
            event:setEntryTag(v.entryTag)

            event:onPreNotifyMod(v.sourceId)

            local target, funcName
            --只向mod实例派发
            if v.useInst then
                target = UBFGameModManagerOrganizer:getRunningModManager(strSourceId)
                funcName = v.funcName and v.funcName or "notifyEvent"
            else
                target = self.modClazzMap[strSourceId]
                funcName = v.funcName and v.funcName or "notifyEventStatic"
            end
            if protectedMode then
                if target == nil then
                    if not v.useInst then
                        -- 可能是没有注册到活动框架里只是纯加分数buff的活动(签到、加分道具、长尾步数升级、贴纸赢好礼等)
                        if UBFLogW then UBFLogW(string.format("[UBFProcessModManager] notifyModEvent %s, mod %s, target is nil", eventName, v.sourceId), UBFTraceback()) end
                        noError = false
                    end
                else
                    local errHandler = string.format("[UBFProcessModManager] notifyModEvent %s, mod %s", eventName, v.sourceId)
                    local strSrcId = tostring(v.sourceId)
                    if eventName == UBFGameModEventEnum.LOAD_MOD and (strSrcId == "guide" or strSrcId == "FeedAutoStart") then
                        local fn = target[funcName]
                        local ok3, err3 = pcall(fn, target, event)
                        -- printx(0, "[MODMGR] " .. strSrcId .. " pcall ok=", tostring(ok3), " err=", tostring(err3))
                        -- printx(0, "[MODMGR] " .. strSrcId .. " enabled after=", tostring(self.modOpenStatusMap[strSrcId]))
                    else
                        local ok = UBFHelper:invokeProtected(target, funcName, errHandler, event)
                        noError = noError and ok
                    end
                end
            else
                UBFHelper:invoke(target, funcName, event)
            end

            event:onPostNotifyMod(v.sourceId)

        end
    end
    self.runtime.sourceId = oldSourceId

    return noError
end

-- 默认按保护模式进行事件派发
function UBFProcessModManager:notifyModEvent(eventName, data)
    return self:_notifyModEvent(eventName, data, true)
end

function UBFProcessModManager:notifyModEventUnprotected(eventName, data)
    return self:_notifyModEvent(eventName, data, false)
end

--启用|禁用一个mod
function UBFProcessModManager:setModEnabled(modId, isEnabled)
    if self.processType == UBFProcessTypeEnum.END_LEVEL then
        UBFThrow("关卡结束流程里禁止调用setModEnabled方法,modId=" .. modId) 
    end
    self:log('mod==>>',modId,isEnabled and "启用" or "禁用")
    self.modOpenStatusMap[modId] = isEnabled
    if isEnabled then
        self:refreshModData(modId)
        -- self:loadModRes(modId)
    else
        self:clearModData(modId)
        -- self:unLoadModRes(modId)
    end
end

--重新刷新已激活的mod的数据
function UBFProcessModManager:refreshModData(modId)
    self:_collectModConditionData(modId)
    local modClazz = self.modClazzMap[tostring(modId)]
    if modClazz then
        local modData = modClazz:createModData(self.runtime)
        self.modDataList[modId] = modData
        self:_loadModResource(modId, modData)
    end
end

function UBFProcessModManager:_loadModResource(modId, modList)
    local modClazz = self.modClazzMap[tostring(modId)]
    if not modClazz then
        -- 没有注册到活动框架里只是纯加分数buff的活动(长尾步数升级、贴纸赢好礼等)，不需要加载资源
        -- he_log_error("modClazz a nil value, modId ==>>".. tostring(modId))
        -- self._last_load_mod_err_ = true
        return 
    end
    local secondaryPrepare = UBFResourceLoadManager:prepare():relax():bestEffort()
    local primaryPrepare = modClazz:createModResPrepare(self.runtime, secondaryPrepare, modList)

    local modFeature = UBFGameModManagerOrganizer:getModFeatureByModList(modList)
    if modFeature and not UBFHelper:isTableEmpty(modFeature) then 
        local UBFResUtils = require 'ubf.UBFPlay.logics.launch.UBFResUtils'
        primaryPrepare = primaryPrepare or UBFResourceLoadManager:prepare()
        local resKeys, scatterList = UBFResUtils:getUnloadResByFeatureMap(modFeature)
        for id, _ in pairs(resKeys) do UBFLVResourceManager:prepare(id, primaryPrepare) end
        for _, res in ipairs(scatterList) do primaryPrepare:add(res) end
        local featureManager = self.runtime.featureManager
        if featureManager then 
            for itemType, _ in pairs(modFeature) do
                featureManager:refreshFeatureByItemType(itemType)
            end
        end
    end

    local sceneReource = self.runtime:getSceneResourceMgr()
    if primaryPrepare then
        sceneReource:setModPrepare(modId, primaryPrepare)
    end
    sceneReource:setModSecondaryPrepare(modId, secondaryPrepare)
end

--清除mod的数据
function UBFProcessModManager:clearModData(modId)
    self.modDataList[modId] = nil
    local sceneReource = self.runtime:getSceneResourceMgr()
    sceneReource:setModPrepare(modId, nil)
    sceneReource:setModSecondaryPrepare(modId, nil)
    if self.modContextData[tostring(modId)] then
        self.modContextData[tostring(modId)].conditionData = nil
    end
end

-- 获取 mod 的条件检测数据（缓存命中返回，否则现场收集并写入缓存）
function UBFProcessModManager:getModConditionData(modId)
    local modContextData = self.modContextData[tostring(modId)]
    if not modContextData then return nil end
    if modContextData.conditionData then
        return modContextData.conditionData
    end
    local modClazz = self.modClazzMap[tostring(modId)]
    if not modClazz then return nil end
    local data = modClazz:collectModConditionData(self.runtime)
    if data then
        modContextData.conditionData = data
    end
    return data
end

function UBFProcessModManager:invalidateModConditionData(modId)
    local modContextData = self.modContextData[tostring(modId)]
    if modContextData then
        modContextData.conditionData = nil
    end
end

function UBFProcessModManager:_collectModConditionData(modId)
    self:getModConditionData(modId)
end

-- --加载mod资源
-- function UBFProcessModManager:loadModRes(modId)
--     local modClazz = self.modClazzMap[modId]
--     modClazz:loadModRes(self.runtime)
-- end

-- --卸载mod资源
-- function UBFProcessModManager:unLoadModRes(modId)
--     local modClazz = self.modClazzMap[modId]
--     modClazz:unLoadModRes(self.runtime)
-- end

--获取mod的激活状态
function UBFProcessModManager:getModEnabled(modId)
    return self.modOpenStatusMap[tostring(modId)]
end

--获取mod上下文数据
function UBFProcessModManager:getModContextData(modId)
    return self.modContextData[tostring(modId)]
end

--获取mod数据
function UBFProcessModManager:getModData(modId)
    return self.modDataList[tostring(modId)]
end

--获取modClazz
function UBFProcessModManager:getModClazz(modId)
    return self.modClazzMap[tostring(modId)]
end

function UBFProcessModManager:getModContextDataMap()
    return self.modContextData
end

--生成游戏最终使用的modList
function UBFProcessModManager:generateGamePlayModList()
    local modList = {}
    for modId, mods in pairs(self.modDataList) do
        if self.modOpenStatusMap[tostring(modId)] then            
            for k , v in ipairs(mods) do 
                if v.sourceId ~= modId and v.env then 
                    UBFThrow "只允许使用自己的sourceId" 
                end
                table.insert(modList, v)
            end
        end
    end
    return modList
end

function UBFProcessModManager:resumeGamePlayModList(modList)
    self.modOpenStatusMap = {}
    self.modDataList = {}
    self.willingModList = {}
    local willingModMap = {}
    for _, data in ipairs(modList) do 
        if data.sourceId then 
            self.modOpenStatusMap[data.sourceId] = true
            if not willingModMap[data.sourceId] then
                willingModMap[data.sourceId] = true
                table.insert(self.willingModList, data.sourceId)
            end
            if not self.modDataList[data.sourceId] then
                self.modDataList[data.sourceId] = {}
            end
            table.insert(self.modDataList[data.sourceId], data)
        end
    end
    table.sort(self.willingModList, function(a, b)
        local na = UBFModHelper:getModPriority(a)
        local nb = UBFModHelper:getModPriority(b)
        return na < nb
    end)
    for modId, list in pairs(self.modDataList) do 
        self:_loadModResource(modId, list)
        if self._last_load_mod_err_ then
            return false
        end
    end
end

function UBFProcessModManager:getModDataList()
    return self.modDataList
end

function UBFProcessModManager:getWillingModList()
    return self.willingModList
end

function UBFProcessModManager:getModOpenStatusMap()
    return self.modOpenStatusMap
end

function UBFProcessModManager:doRevert()
    for k, modId in pairs(self.willingModList) do
        local modClazz = self.modClazzMap[tostring(modId)]
        if modClazz then
            modClazz:doRevert(self.runtime)
        end
    end
    self:resetData()
end

function UBFProcessModManager:resetData()
    self.willingModList = {}
    self.modOpenStatusMap = {}
    self.modContextData = {}
    self.modDataList = {} 
end

function UBFProcessModManager:log(...)
    if EnvUtil:isDevelopMode() and not _G.AutoPlayEnv then
        UBFLogI("UBFProcessModManager==>>>：", ...)
    end
end
