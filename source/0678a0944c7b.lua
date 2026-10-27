local Const = {}

Const.GuideSetId = {
    
}

Const.actOpenVersion = 1            -- 活动开启周期，如果需要本地数据变更，或者升版本清数据啥的用
Const.actId = 8074                  -- 活动actId，朴实无华 
Const.actChName = "冲关回馈"            -- 活动中文名
Const.actSource = "sprintgiftpackage/Config.lua"  -- 活动路径

Const.dcFeature = "activity" -- 打点用

Const.infoPrefix = "userInfo.data"       -- 数据keyChain前缀，可以没有，说明你直接存在data里，没再加个表
Const.configPrefix = "localConfig"  -- 配置keyChain前缀，同上
Const.timePrefix = "userInfo"

Const.downloadLabels = {

}
Const.autoDownload = false
Const.actColorType = _G.PanelColorConst.ColorType.kGreen
Const.GAME_NAME = ""
Const.popTip2 = "mainTimeAllTaskDonePop"
Const.popTip3 = "rewardTimeNeedBuyPop"
Const.popTip4 = "rewardTimeBoughtNeedClaimPop"
Const.addFiveShowTimeStr = "addFiveShowTime"
Const.historyLevelStatus = "historyLevelStatus"

Const.HapticsConfig = {
    changeToGet = {
        strength = 1,
        richTap = {
            path = "he2/act/sprintgiftpackage/change_to_get.he",
        },
        default = {
            data={50, 128}
        },
        -- miniGame = {
        --     level = "light"
        -- }
    },
    clickGet = {
        strength = 1,
        richTap = {
            path = "he2/act/sprintgiftpackage/click_get.he",
        },
        default = {
            data={50, 128}
        },
        -- miniGame = {
        --     level = "light"
        -- }
    },
    clickProgress = {
        strength = 1,
        richTap = {
            path = "he2/act/sprintgiftpackage/click_progress.he",
        },
        default = {
            data={50, 128}
        },
        -- miniGame = {
        --     level = "light"
        -- }
    },
    playDiscount = {
        strength = 1,
        richTap = {
            path = "he2/act/sprintgiftpackage/play_discount.he",
        },
        default = {
            data={50, 128}
        },
        -- miniGame = {
        --     level = "light"
        -- }
    },
}

Const.changeToGetHaptic = "changeToGet"
Const.clickGetHaptic = "clickGet"
Const.clickProgressHaptic = "clickProgress"
Const.playDiscountHaptic = "playDiscount"
Const.timeOutTipMinTime = 30*60
Const.timeOutTipMaxTime = 60*60*24
Const.addFiveSteps = "addFiveSteps"
Const.shopPanel = "shopPanel"
Const.NormalSkin = "Normal"
Const.SpecialSkin = "Special"

return Const