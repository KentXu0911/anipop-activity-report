return {
    actItemConfig = {
        [1] = {
            actItemId = "10",
            iconConfig = {
                [1] = {
                    rawData = {
                        frameName = "LuckyBagParty_coms/f_coin",
                        plist = "tempFunctionResInLevel/LuckyBagParty/png/LuckyBagParty_coms.plist",
                        type = "image",
                    },
                    scene = "default",
                },
            },
        },
        [2] = {
            actItemId = "11",
            iconConfig = {
                [1] = {
                    rawData = {
                        frameName = "LuckyBagParty_coms/f_energy",
                        plist = "tempFunctionResInLevel/LuckyBagParty/png/LuckyBagParty_coms.plist",
                        type = "image",
                    },
                    scene = "default",
                },
            },
        },
    },
    actOpenConditionConfig = {
        __treeId = "209",
        path = "ROOT/Animal/UBFGameScene/enableActivitys/act_6038",
        trigger = {
            [1] = "checkBaseCondition",
            [2] = "finishBeforeStartLevel",
            [3] = "startWaiting",
            [4] = "destoryAnimal",
            [5] = "beforeWaitingState",
        },
        version = 2,
    },
    addFiveStepConfig = {
        iconConfig = {
            [1] = {
                appearInContent = {
                    [1] = 5,
                    [2] = 9,
                },
                displayPriority = 10000,
                iconName = "10",
                iconTopLabelTypes = {
                },
                panelText = "现在退出会失去大量收集物",
                touchTipText = "【福袋派对】消除福袋获得",
            },
            [2] = {
                appearInContent = {
                    [1] = 5,
                    [2] = 9,
                },
                displayPriority = 10000,
                iconName = "11",
                iconTopLabelTypes = {
                },
                panelText = "现在退出会失去大量收集物",
                touchTipText = "【福袋派对】消除福袋获得",
            },
        },
        needSecondConfirm = false,
        usePropRewardConfig = {
        },
        usePropRewardTimesIsShared = true,
    },
    baseConfig = {
        ActivityCHName = "福袋派对",
        ActivityName = "LuckyBagParty",
        actMainManager = "LuckyBagPartyMgr",
        collectionIds = {
            [1] = "10",
            [2] = "11",
        },
        customLoader = "LuckyBagPartyActLoader",
        featureId = "6038",
        mainMgrName = "LuckyBagPartyActManager",
        needFuuuTargetProgressData = true,
    },
    -- collectBarConfig = {
    --     [1] = {
    --         alwaysShow = false,
    --         canClick = true,
    --         emphasize = true,
    --         iconID = "10",
    --         index = 1,
    --         isNeedCustom = true,
    --         isStable = false,
    --         value = 0,
    --     },
    --     [2] = {
    --         alwaysShow = false,
    --         canClick = true,
    --         emphasize = true,
    --         iconID = "11",
    --         index = 1,
    --         isNeedCustom = true,
    --         isStable = false,
    --         value = 0,
    --     },
    -- },
    constraintVer = 170,
    modifyVersion = 14,
    releaseVersion = 0,
    ubfItemStaticConfig = {
        [1] = {
            actLogicName = "LuckyBagPartyActEventLogic",
            isActCore = true,
            itemContextName = "LuckyBagPartyItemContext",
            itemType = "LuckyBagParty",
            priority = 0,
        },
    },
    version = 3,
}