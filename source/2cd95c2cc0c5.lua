return {
    actItemConfig = {
        [1] = {
            actItemId = "48",
            iconConfig = {
                [1] = {
                    rawData = {
                        frameName = "PreColorfulStar_res/colorfulStar_inner0000",
                        plist = "ubfRes/ui/mod/PreColorfulStar/InLevelRes.plist",
                        type = "image",
                    },
                    scene = "default",
                },
            },
        },
    },
    actOpenConditionConfig = {
        __treeId = "223",
        path = "ROOT/Animal/UBFGameScene/enableActivitys/act_5301",
        trigger = {
            [1] = "checkBaseCondition",
        },
        version = 4,
    },
    addFiveStepConfig = {
        iconConfig = {
            [1] = {
                appearInContent = {
                    [1] = 5,
                    [2] = 9,
                },
                containCollectionIds = {
                    [1] = "48",
                },
                displayPriority = 10000,
                iconName = "48",
                iconTopLabelTypes = {
                    [1] = 8,
                },
                panelText = "退出会失去彩星集分瓶奖励",
                touchTipText = "彩星集分瓶",
            },
        },
        needSecondConfirm = false,
        usePropRewardConfig = {
        },
        usePropRewardTimesIsShared = true,
    },
    baseConfig = {
        ActivityCHName = "彩星竞赛",
        ActivityName = "PreColorfulStar",
        actMainManager = "PreColorfulStarManager",
        collectionIds = {
            [1] = "48",
        },
        featureId = "5301",
        mainMgrName = "PreColorfulStarActManager",
        needFuuuTargetProgressData = false,
    },
    constraintVer = 164,
    modifyVersion = 9,
    releaseVersion = 0,
    scoreBarConfig = {
        scoreBarColorBlendConfig = {
            autoUpdate = false,
            blendID = "PreColorfulStar",
            colorBlendData = {
                [1] = {
                    colorBlendType = 1,
                    colorFile = "PreColorfulStar/progressMask1",
                    colorID = "pink",
                    colorWidth = 1,
                    mixLeft = 0.3,
                    percentageImg = 0.001,
                    percentageNum = 0.001,
                },
                [2] = {
                    colorBlendType = 1,
                    colorFile = "PreColorfulStar/progressMask2",
                    colorID = "yellow",
                    colorWidth = 1,
                    mixLeft = 0.3,
                    percentageImg = 0.001,
                    percentageNum = 0.001,
                },
            },
        },
    },
    ubfItemStaticConfig = {
        [1] = {
            actLogicName = "PreColorfulStarActEventLogic",
            isActCore = true,
            itemContextName = "PreColorfulStarActContext",
            itemType = "PreColorfulStar",
            priority = 0,
        },
    },
    version = 3,
}