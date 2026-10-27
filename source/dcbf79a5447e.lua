require "amf.feature.winningstreak.config.WSConst"

-- 顺序就是优先级，越前优先级越高
local WSModuleConfig = {
    {
        name = WSConst.ModuleType.TROPHY,
        actId = 4030,
        active = true,
        modulePath = "amf.feature.winningstreak.module.trophy.TrophyModule",
        mgrPath = "amf.feature.winningstreak.module.trophy.TrophyManager",
        stageTypeList = {
            WSConst.StageType.START_PANEL,
            WSConst.StageType.PASS_PANEL,
        },
        strategyTypeList = {WSConst.WinNumStrategyType.FMJ_TOP},
    },
    {
        name = WSConst.ModuleType.MEME_FOX,
        actId = 4042,
        active = true,
        modulePath = "amf.feature.winningstreak.module.memefox.MeMeFoxModule",
        mgrPath = "amf.feature.winningstreak.module.memefox.MeMeFoxManager",
        stageTypeList = {
            WSConst.StageType.START_PANEL,
            WSConst.StageType.PASS_PANEL,
            WSConst.StageType.SINGLE_ICON,
            WSConst.StageType.TOP_FLOWER,
        },
        strategyTypeList = {
            WSConst.WinNumStrategyType.FMJ_TOP,
            WSConst.WinNumStrategyType.MJFMC_FULL_STAR,
        },
    },

    {
        name = WSConst.ModuleType.BOTTLE,
        actId = 9064,
        active = true,
        modulePath = "amf.feature.winningstreak.module.bottle.WinningStreakBottleModule",
        mgrPath = "amf.feature.winningstreak.module.bottle.WinningStreakBottleManager",
        stageTypeList = {
            WSConst.StageType.SINGLE_ICON,
        },
        strategyTypeList = {
            WSConst.WinNumStrategyType.FMJ_TOP,
            WSConst.WinNumStrategyType.MJFMC_ANY_LEVEL,
        },
    },
    {
        name = WSConst.ModuleType.COLORFUL_STAR,
        actId = 8055,
        active = true,
        modulePath = "amf.feature.winningstreak.module.colorfulstar.ColorfulStarWinRepeatModule",
        mgrPath = "amf.feature.winningstreak.module.colorfulstar.ColorfulStarWinRepeatManager",
        stageTypeList = {
            WSConst.StageType.START_PANEL,
            WSConst.StageType.PASS_PANEL,
        },
        strategyTypeList = {
            WSConst.WinNumStrategyType.MJFMC_FULL_STAR,
        },
    },
    {
        name = WSConst.ModuleType.MUSICMASTER,
        actId = 4062,
        active = true,
        modulePath = "amf.feature.winningstreak.module.musicmaster.MusicMasterWSModule",
        mgrPath = "amf.feature.localactivity.musicmaster.MusicMasterManager",
        stageTypeList = {
            WSConst.StageType.START_PANEL,
            WSConst.StageType.PASS_PANEL,
            WSConst.StageType.SINGLE_ICON,
        },
        strategyTypeList = {
            WSConst.WinNumStrategyType.FMJ_TOP,
            WSConst.WinNumStrategyType.MJFMC_FULL_STAR,
            WSConst.WinNumStrategyType.MJMC_LEVEL_LIB,
        },
    }
}

return WSModuleConfig
