local UBFLSPreheatProcess = class2("UBFLSPreheatProcess", UBFProcessNode)

function UBFLSPreheatProcess:doProcess()
    local runtime = self:get("runtime")
    UBFPlayLogicLauncher:tryPreloadThread()
    if EnvUtil:isMiniGame() then
        if runtime:isReplayMode() then
        elseif runtime:isEditorMode() then 
        else
            local UBFuuuAdjustManager = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager"
            if UBFuuuAdjustManager then 
                UBFuuuAdjustManager:checkUpdateDiffDsMapByLevelId(runtime:getLevelId(), runtime.levelScene)
            end
        end
    else
        local UBFuuuAdjustManager = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager"
        if UBFuuuAdjustManager then
            UBFuuuAdjustManager:checkUpdateDiffDsMapByLevelId(runtime:getLevelId(), runtime.levelScene)
        end

    end
    self:success()
end

function UBFLSPreheatProcess:doRevert()
end

return UBFLSPreheatProcess