local UBFSLModInitProcess = class2("UBFSLModInitProcess", UBFProcessNode)

function UBFSLModInitProcess:doProcess()
    --@ UBFStartLevelLogic:createModRunTime 只是近似于旧棋盘的，单流程肯定不一样
    local runtime = self:get("runtime")
    local modMgr = runtime:getModMgr()

    --初始化生成所有本次启动预期的mod
    modMgr:loadAllWillingMod()
    self:dispatchModEvent(UBFGameModEventEnum.START)

    local tallySkinMap = {}
    self:dispatchModEvent(UBFGameModEventEnum.MODIFY_TALLY_SKIN_RES, {
        tallySkinMap = tallySkinMap,
    })
    UBFSetCustomTallyIconSkinMap(tallySkinMap)

    self:success()
end

function UBFSLModInitProcess:doRevert()
    local runtime = self:get("runtime")
    local modMgr = runtime:getModMgr()
    modMgr:doRevert()

    UBFSetCustomTallyIconSkinMap(nil)
end

return UBFSLModInitProcess