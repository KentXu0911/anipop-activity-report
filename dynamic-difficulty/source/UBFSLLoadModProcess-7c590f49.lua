local UBFSLLoadModProcess = class2("UBFSLLoadModProcess", UBFProcessNode)

function UBFSLLoadModProcess:doProcess()
    local runtime = self:get("runtime")
    UBFProcessAmfDataHelper:loadModData(runtime)
    self:dispatchModEvent(UBFGameModEventEnum.LOAD_MOD)
    self:success()
end

function UBFSLLoadModProcess:doRevert()
    self:dispatchModEvent(UBFGameModEventEnum.REVERT_LOAD_MOD)
end

return UBFSLLoadModProcess
