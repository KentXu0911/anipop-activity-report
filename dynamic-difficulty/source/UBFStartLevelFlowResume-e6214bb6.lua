local config = {
    [UBFProcessNodeEnum.BASE_INFO] = {
        name = "构建基础视图/数据配置",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLBaseInfoProcess',
    },
    [UBFProcessNodeEnum.MOD_INIT] = {
        name = "mod系统启动",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLModInitProcess',
        prev = { UBFProcessNodeEnum.BASE_INFO },
    },
    [UBFProcessNodeEnum.LOAD_RESOURCE] = { 
        name = "创建加载的prepare",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLLoadResourceProcess',
        prev = { UBFProcessNodeEnum.MOD_INIT },
    },
    [UBFProcessNodeEnum.RESUME_START] = {
        name = "闪退恢复开始",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLResumeStartProcess',
        prev = {
            UBFProcessNodeEnum.MOD_INIT,
            UBFProcessNodeEnum.LOAD_RESOURCE,
        }
    },
    [UBFProcessNodeEnum.PREPARE_START_DATA] = { 
        name = "准备启动数据",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLBeforeStartProcess',
        prev = { UBFProcessNodeEnum.RESUME_START },
    },
    [UBFProcessNodeEnum.LAUNCH_LOGIC] = { 
        name = "启动逻辑线程",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLLaunchLogicProcess',
        prev = { 
            UBFProcessNodeEnum.PREPARE_START_DATA,
        }
    },
    [UBFProcessNodeEnum.WAIT_RESOURCE_READY] = {
        name = "等待资源加载完成",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLWaitResourceReadyProcess',
        prev = { 
            UBFProcessNodeEnum.PREPARE_START_DATA,
        },
    },
    [UBFProcessNodeEnum.LAUNCH_SCENE] = { 
        name = "启动场景",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLLaunchSceneProcess',
        prev = { UBFProcessNodeEnum.WAIT_RESOURCE_READY, }
    },
    [UBFProcessNodeEnum.LAUNCH_BOARD_VIEW] = {
        name = "启动棋盘",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLLaunchBoardProcess', 
        prev = {
            UBFProcessNodeEnum.LAUNCH_LOGIC,
            UBFProcessNodeEnum.LAUNCH_SCENE,
        }
    },
    [UBFProcessNodeEnum.PROCESS_FLOW_FINISHED] = {
        name = "关卡流程结束",
        triggerMode = UBFProcessTriggerModeEnum.ALL,
        prev = { UBFProcessNodeEnum.LAUNCH_BOARD_VIEW},
    },
}

return config