require "amf.feature.localactivity.supermagicbird.SmbDebug"

local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"

local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"

local SuperMagicBirdMoney2025Manager = class("SuperMagicBirdMoney2025Manager",BaseFeatureManager)
-- _G.SuperMagicBirdMoney2025Manager = SuperMagicBirdMoney2025Manager

SuperMagicBirdMoney2025Manager.ACT_OPEN_VERSION = 1  --如果此活动复用 此值应递增 以区分本地存储值

-- 主线
SuperMagicBirdMoney2025Manager.ACT_ID = 8069

-- local instance = nil
-- function SuperMagicBirdMoney2025Manager.getInstance()  
--     if instance then return instance end
--     instance = SuperMagicBirdMoney2025Manager.new()
--     instance:init()
--     return instance
-- end
local ACT_NAME = "supermagicbirdmoney2025"
local LOCAL_PATH = 'amf.feature.localactivity.'..string.lower( ACT_NAME )

-- function SuperMagicBirdMoney2025Manager.getOrCreateInstance()  
--     return SuperMagicBirdMoney2025Manager.getInstance()  
-- end

function SuperMagicBirdMoney2025Manager:_getExtraPlugsConfigList()
    return {
    }
end

function SuperMagicBirdMoney2025Manager:_getModelPath()
    return LOCAL_PATH..'.model.SuperMagicBirdMoneyModel'
end

function SuperMagicBirdMoney2025Manager:_getConstPath()
    return LOCAL_PATH..'.config.SuperMagicBirdMoneyConst'
end

function SuperMagicBirdMoney2025Manager:getData()
    return self:getModel()
end

function SuperMagicBirdMoney2025Manager:registerEvents()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
end

function SuperMagicBirdMoney2025Manager:_init()
    -- UError("SuperMagicBirdMoney2025Manager:init___")
    self:registerEvents()
    -- self.Notify = require "amf/feature/localactivity/supermagicbird/data/Notify"
    -- self.Notify:register("SuperMagicBirdActGetGold", function( from, gold )
    --     self:getData():subActAddGold( from, gold )
    -- end)
    _G.amfEC:registerNormal("SuperMagicBirdActGetGold", function( evt )
        -- UError("SuperMagicBirdActInfoUpdateEVT",tts(evt))
        self:getData():subActAddGold( evt.data.from, evt.data.gold )
    end)
end

function SuperMagicBirdMoney2025Manager:onActActInfoUpdate(event)

    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(SuperMagicBirdMoney2025Manager.ACT_ID)]

    if fromServer and actInfo then
        --同步最新后端内容
        if actInfo.extra then
            local extra = table.deserialize(actInfo.extra)
            if extra then
                -- self:getData():fromSever(extra)
                self:getData():fromActInfo(extra)
            end
        end
    end
end


function SuperMagicBirdMoney2025Manager:getPlayLevelState(levelId, levelScene )
    local levelState = 0
    if LevelSceneFunc:isFullLevelLib(levelScene) then 
        levelState = 3
    elseif LevelSceneFunc:isMainLevel(levelScene) then 
        levelState = UBFActHelper:getPlayLevelModeType(levelId, nil, levelScene) 

        local isFMJ = _G.amfBean("UserStateManager"):isFMJ()
        if levelState == 2 and isFMJ then
            levelState = 0
        end

        if levelState ~= 1 and levelState ~= 2 then 
            levelState = 0
        end
    end
    return levelState
end

function SuperMagicBirdMoney2025Manager:onActBeforeStartLevel(evt)
    local data = evt.data
    if not data or not data.levelId then return end
    if not data or not data.levelScene then return end

    local levelState = self:getPlayLevelState( data.levelId, data.levelScene )
    data.target:setOutLevelAttachData("super_bird", levelState)
end

function SuperMagicBirdMoney2025Manager:onActBeforePlayLevelEnd(evt)

    local data = evt.data
    if not data or not data.levelId then return end
    if _G.amfBean("AskForHelpManager"):hasAskForHelpInfo(data.levelId ) then return end

    local inst = UBFGameSceneManager:getInstance()
    local levelInfo = inst:getLevelInfo()
    -- if levelInfo.levelId ~= levelInfo.topLevelId then return end

    local levelState = 0
    if levelInfo.outLevelAttachData and levelInfo.outLevelAttachData["super_bird"] then
        levelState = levelInfo.outLevelAttachData["super_bird"]
    end

    if levelState == 0 then return end 

    local pworth = inst:getSceneData().pworth or {}

    local actInLevelManager = UBFGameModManagerOrganizer:getRunningModManager(8068)
    local modEnv = actInLevelManager and actInLevelManager:getModEnvData()
    local hasSuperPower = modEnv and modEnv.hasSuperPower

    -- local endLevelData = inst:getEndLevelData()

    data.jsonTable["8069"] = { propWorth = pworth["MX"], levelState = levelState, propWorthV2 = pworth["RY"] }

    --
    self:getData():passLevelAddGoldNum(levelInfo.levelId, pworth["MX"], hasSuperPower, data.isWin, levelState)
    self:getData():passLevelAddGoldNumV2(levelInfo.levelId, pworth["RY"], hasSuperPower, data.isWin, levelState)
    self:getData():addCurCost( levelInfo.levelId, levelInfo.levelScene, pworth["RY"] )
end

function SuperMagicBirdMoney2025Manager:onActDcStageQuit(evt)

    local data = evt.data
    self:onActDcStageEnd(data)
end

function SuperMagicBirdMoney2025Manager:onActDcStageEnd(data)
    local dcDatas = data
    local inst = UBFGameSceneManager:getInstance()
    if not inst then return end
    if not dcDatas.actInfo then dcDatas.actInfo = {} end
    local sceneData = inst:getSceneData()
    dcDatas.actInfo[tostring(self.ACT_ID)] = {
        t1 = sceneData.pworth and sceneData.pworth["MX"],
    }
end

return SuperMagicBirdMoney2025Manager