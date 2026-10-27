--注意，这个类的创建必须有始有终，要么完成了(isFinished)，要么放弃了(isAborted)，才允许丢弃引用
--! 详细文档请参考UBFProcess.lua最开头的大段注释
UBFSLProcessFlowController = class2("UBFSLProcessFlowController", UBFProcessFlowController)

local migrator = require('ubf.UBFGamePlayScene.logics.processFlow.module.UBFSLMigrator')

--获取默认启动关卡的任务流程
function UBFSLProcessFlowController:getDefaultStartLevelProcessCreateData()
    if EnvUtil:isMiniGame() then
        return {
            name = "启动关卡(小程序)",
            finProcessKey = UBFProcessNodeEnum.PROCESS_FLOW_FINISHED,
            processFlowConfig = require 'ubf.UBFGamePlayScene.logics.processFlow.config.UBFStartLevelFlowMiniNormal',
            dynamicProcessFlowConfig = require 'ubf.UBFGamePlayScene.logics.processFlow.config.UBFStartLevelFlowDynamic',
            migrator = migrator.normal,
        }
    end
    return {
        name = "启动关卡",
        finProcessKey = UBFProcessNodeEnum.PROCESS_FLOW_FINISHED,
        processFlowConfig = require 'ubf.UBFGamePlayScene.logics.processFlow.config.UBFStartLevelFlowNormal',
        dynamicProcessFlowConfig = require 'ubf.UBFGamePlayScene.logics.processFlow.config.UBFStartLevelFlowDynamic',
        migrator = migrator.normal,
    }
end

--获取默认手动关卡的任务流程
function UBFSLProcessFlowController:getManualStartLevelProcessCreateData()
    return {
        name = "启动关卡(强弹)",
        finProcessKey = UBFProcessNodeEnum.PROCESS_FLOW_FINISHED,
        processFlowConfig = require 'ubf.UBFGamePlayScene.logics.processFlow.config.UBFStartLevelFlowManualPop',
        migrator = migrator.normal,
    }
end

--获取重玩关卡启动流程
function UBFSLProcessFlowController:getRetryStartLevelProcessCreateData()
    return {
        name = "重试关卡",
        finProcessKey = UBFProcessNodeEnum.PROCESS_FLOW_FINISHED,
        processFlowConfig = require 'ubf.UBFGamePlayScene.logics.processFlow.config.UBFStartLevelFlowRetry',
        dynamicProcessFlowConfig = require 'ubf.UBFGamePlayScene.logics.processFlow.config.UBFStartLevelFlowDynamic',
        migrator = migrator.normal,
    }
end

--精彩回放任务流程
function UBFSLProcessFlowController:getWonderfulReplayLevelProcessCreateData()
    return {
        name = "精彩回放",
        finProcessKey = UBFProcessNodeEnum.PROCESS_FLOW_FINISHED,
        processFlowConfig = require 'ubf.UBFGamePlayScene.logics.processFlow.config.UBFStartLevelFlowReplay',
    }
end

-- 调试回放
function UBFSLProcessFlowController:getDebugReplayLevelProcessCreateData()
    return {
        name = "调试回放",
        finProcessKey = UBFProcessNodeEnum.PROCESS_FLOW_FINISHED,
        processFlowConfig = require 'ubf.UBFGamePlayScene.logics.processFlow.config.UBFStartLevelFlowReplay',
    }
end

function UBFSLProcessFlowController:getResumeStartLevelProcessCreateData()
    return {
        name = "闪退恢复",
        finProcessKey = UBFProcessNodeEnum.PROCESS_FLOW_FINISHED,
        processFlowConfig = require 'ubf.UBFGamePlayScene.logics.processFlow.config.UBFStartLevelFlowResume',
        migrator = migrator.resume,
    }
end

--获取编辑器启动关卡的任务流程
function UBFSLProcessFlowController:getEditorStartLevelProcessCreateData()
    return {
        name = "编辑器关卡",
        finProcessKey = UBFProcessNodeEnum.PROCESS_FLOW_FINISHED,
        processFlowConfig = require 'ubf.UBFGamePlayScene.logics.processFlow.config.UBFStartLevelFlowEditor',
    }
end

function UBFSLProcessFlowController:init(createData) 
	UBFProcessFlowController.init(self, createData)
    self:setResult("runtime", createData.runtime) -- 不一定开始就有
    --代码迁移听众
    local migrator = createData.migrator
    if migrator then 
        for key, func in pairs(migrator.after or {}) do
            self:after(key):next(function() func(self:getResult("runtime")) end)
        end
        for key, func in pairs(migrator.before or {}) do
            self:before(key):next(function() func(self:getResult("runtime")) end)
        end
    end
end

function UBFSLProcessFlowController:getProcessType()
    return UBFProcessTypeEnum.START_LEVEL
end

function UBFSLProcessFlowController:onEndLevelProcessFinish()
    self:operate(UBFProcessNodeEnum.RETRY_END, { isOver = true })
end

function UBFSLProcessFlowController:_end()
    UBFProcessFlowController._end(self)

    local runtime = self:getResult("runtime")
    runtime:cleanup()
    runtime:onProcessEnd()
end

function UBFSLProcessFlowController:_abort(node)
    UBFProcessFlowController._abort(self, node)

    local runtime = self:getResult("runtime")
    if not runtime then return end
    runtime:cleanup()
    runtime:onProcessEnd()
end
