require 'ubf.UBFGamePlayScene.logics.sceneModules.gameMod.UBFGameBaseModManager'
UBFGameModManager = class2( "UBFGameModManager" , UBFGameBaseModManager )

function UBFGameModManager:createModData(runtime)
    local sourceId = runtime.sourceId
    local builderCls = self:getModDataBuilderClass()
    local builder
    if builderCls then
        builder = builderCls:create()
    end
    -- Mod启动数据
    local modSourceENVData

    -- if runtime.aiMode then
    if _G.AI_PLAY_GAME_MODE then
        --AI自动打关
        local sourceId = sourceId
        local actData = sourceId and runtime.ai_actDataMap and runtime.ai_actDataMap[sourceId]
        modSourceENVData = self:createModSourceENVDataFromAIAutoPlay(runtime, actData)
    elseif runtime.editorMode then
        --编辑器模式
        modSourceENVData = self:createModSourceENVDataFromEditorPlay(runtime)
    else
        --正常打关模式
        modSourceENVData = self:createModSourceENVDataFromPlay(runtime)
    end

    if builder then
        builder:setModSourceENV( sourceId , modSourceENVData )
        return builder:toCreateDatas() 
    end
    
    return modSourceENVData
end

function UBFGameModManager:createModSourceENVDataFromEditorPlay(ubfSLRuntime)
    local modEnvData = self:createRandomLevelContext(ubfSLRuntime)
    return modEnvData
end

function UBFGameModManager:createRandomLevelContext(ubfSLRuntime)
    local modEnvData = {}

    return modEnvData
end

function UBFGameModManager:createModSourceENVDataFromAIAutoPlay(ubfSLRuntime, actData)
end

function UBFGameModManager:getModDataBuilderClass()
    return UBFPlayModBuilder
end

function UBFGameModManager:notifyEvent( event )
    local eventName = event:getEventName()
    local funcKey = "on" .. eventName
    if self[funcKey] then
        self[funcKey](self, event)
    end
end 
