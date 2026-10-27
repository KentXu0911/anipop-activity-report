local config = {
    [UBFProcessNodeEnum.PREHEART] = {
        name = "线程等预热",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLPreheatProcess'
    },
    [UBFProcessNodeEnum.SL_CHECK_RUNTIME] = {
        name = "检查Runtime",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLCheckRuntimeProcess',
    },
    [UBFProcessNodeEnum.SL_PRE_INIT] = {
        name = "启动基础数据准备",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLPreInitProcess',
        prev = { UBFProcessNodeEnum.SL_CHECK_RUNTIME },
    },
    [UBFProcessNodeEnum.BASE_INFO] = {
        name = "构建基础视图/数据配置",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLBaseInfoProcess',
        prev = { UBFProcessNodeEnum.SL_PRE_INIT },
    },
    [UBFProcessNodeEnum.MOD_INIT] = {
        name = "mod系统启动",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLModInitProcess',
        prev = { UBFProcessNodeEnum.BASE_INFO },
    },
    [UBFProcessNodeEnum.START_PANEL] = {
        name = "打开开始面板",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLStartPanelProcess',
        prev = { UBFProcessNodeEnum.MOD_INIT },
    },
    [UBFProcessNodeEnum.LOAD_RESOURCE] = {
        name = "创建加载的prepare",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLLoadResourceProcess',
        prev = { UBFProcessNodeEnum.START_PANEL },
    },
    [UBFProcessNodeEnum.CHECK_EENERY] = {
        name = "检查精力，使用精力道具",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLCheckEneryProcess',
        prev = { UBFProcessNodeEnum.MOD_INIT },
    },
    [UBFProcessNodeEnum.FLY_ENERGY] = { 
        name = "飞精力动画，并通知面板关闭",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLPlayEnergyProcess',
        prev = { UBFProcessNodeEnum.CHECK_EENERY } 
    },
    [UBFProcessNodeEnum.RETRY_END] = {
        name = "通知并等待当前游戏结束",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLRetryEndProcess',
        prev = { UBFProcessNodeEnum.CHECK_EENERY } 
    },
    [UBFProcessNodeEnum.SEND_START_LEVEL_MSG] = { 
        name = "发送startlevel，并进行精力消耗处理",
        -- 这个节点会在前置节点完成后被自动唤起，假如这个节点的某个[动作]失败了(fail)了
        -- 就绪停留在这个[动作]前，之后必须手动重新唤起(launch)
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLSendStartLevelProcess',
        prev = { UBFProcessNodeEnum.RETRY_END } 
    },
    [UBFProcessNodeEnum.LOAD_MOD] = { 
        name = "进关前mod最后一次处理启用",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLLoadModProcess',
        prev = {
            UBFProcessNodeEnum.SEND_START_LEVEL_MSG,
            UBFProcessNodeEnum.LOAD_RESOURCE,
        }
    },
    [UBFProcessNodeEnum.PREPARE_START_DATA] = { 
        name = "准备启动数据",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLBeforeStartProcess',
        prev = { UBFProcessNodeEnum.LOAD_MOD }  
    },
    [UBFProcessNodeEnum.DC_START_LEVEL] = { 
        name = "StageLevel打点",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLDCStartLevelProcess',
        prev = { UBFProcessNodeEnum.LAUNCH_SCENE }  
    },
    [UBFProcessNodeEnum.LAUNCH_LOGIC] = { 
        name = "启动逻辑线程",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLLaunchLogicProcess',
        prev = { 
            UBFProcessNodeEnum.PREHEART, 
            UBFProcessNodeEnum.PREPARE_START_DATA,
        }
    },
    [UBFProcessNodeEnum.WAIT_RESOURCE_READY] = {
        name = "等待资源加载完成",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLWaitResourceReadyProcess',
        prev = { 
            UBFProcessNodeEnum.PREPARE_START_DATA,
            UBFProcessNodeEnum.FLY_ENERGY,
        },
    },
    [UBFProcessNodeEnum.LAUNCH_SCENE] = { 
        name = "启动场景",
        logic = 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLLaunchSceneProcess',
        prev = {
            UBFProcessNodeEnum.WAIT_RESOURCE_READY,
        }
    },
    --这个流程节点有两个前置流程，都完成后才会被唤起
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
        prev = { UBFProcessNodeEnum.LAUNCH_BOARD_VIEW, UBFProcessNodeEnum.DC_START_LEVEL},
    },
}

return config