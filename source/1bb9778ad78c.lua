local Res = {}

local RES_TOOT = "amf/dailylevel/"
local function _getSpinePath(name)
    return RES_TOOT.."spine/"..name
end

local function _getTexturePath(name)
    return RES_TOOT.."texture/"..name
end

local function _getMusicPath(name)
    return RES_TOOT.."music/"..name
end

local function _getLoadingPath(name)
    return RES_TOOT.."loading/"..name
end

local function _getLoadingTexturePath(name)
    return _getLoadingPath("texture/"..name)
end

local function _getLoadingSpinePath(name)
    return _getLoadingPath("spine/"..name)
end

local function _getIconSpinePath(name)
    return RES_TOOT.."icon/"..name
end

Res.Spine = {
    BOX_EFF_LVUP = _getSpinePath("box_eff_lvup.skel"),
    BOX = _getSpinePath("box.skel"),
    FX_BOX = _getSpinePath("fx_box.skel"),
    QUAN = _getSpinePath("quan.skel"),
    QUAN_GLOW = _getSpinePath("quan_glow.skel"),
    PRIZE_REWARD_VFX = _getSpinePath("jiangli_vfx.skel"),
    PRIZE_TICKET_CONVERT = _getSpinePath("zhuanhuan.skel"),
    PRIZE_FIREWORK = _getSpinePath("lihua.skel"),
    PRIZE_FIREWORK_FULL_SCREEN = _getSpinePath("lihua2.skel"),
    GEM_DOUBLE = _getSpinePath("gem_double.skel"),
    COLLECTION_GEM = _getSpinePath("born_baoshi_outside.skel"),
    MOLE_MAGE = _getSpinePath("MoleMage.skel"),
    NVWANGE = _getSpinePath("nvwang.skel"),
    WEEKEND_NVWANG = _getSpinePath("weekend/nvwang.skel"),
    CARD = _getSpinePath("card.skel"),
    NEW_ROUND_BANNER = _getSpinePath("banner.skel"),
    LOADING = _getLoadingSpinePath("loading.skel"),
    ICON_WEEKDAY = _getIconSpinePath("richang_old.skel"),
    ICON_WEEKEND = _getIconSpinePath("zhoumo_old.skel"),
    ICON_WEEKDAY_V2 = _getIconSpinePath("richang_new.skel"),
    ICON_WEEKEND_V2 = _getIconSpinePath("zhoumo_new.skel"),
}

Res.Texture = {
    MAINBG = _getTexturePath("mainBg.png"),
    MAINBG_WEEKEND = _getTexturePath("mainBgWeekend.png"),
    WEEKEND_FRONT = _getTexturePath("weekendFront.png"),
    LOADING_ATLAS = _getLoadingTexturePath("DailyLevelLoading.plist"),
    ICON_WEEKDAY_MINIGAME = _getIconSpinePath("richang_minigame.png"),
    ICON_WEEKEND_MINIGAME = _getIconSpinePath("zhoumo_minigame.png"),
}

Res.SpriteFrame = {
    LOADING_NORMAL_BG = "MeiRiYiGuan/DailyLevelLoading/normalBg",
    LOADING_NORMAL_DECO = "MeiRiYiGuan/DailyLevelLoading/normalDeco",
    LOADING_NORMAL_IMG = "MeiRiYiGuan/DailyLevelLoading/normalImg",
    LOADING_WEEKEND_BG = "MeiRiYiGuan/DailyLevelLoading/weekEndBg",
    LOADING_WEEKEND_DECO = "MeiRiYiGuan/DailyLevelLoading/weekEndDeco",
    LOADING_WEEKEND_IMG = "MeiRiYiGuan/DailyLevelLoading/weekEndImg",
}

Res.Music = {
    PROGRESS_BOX_CLICK = _getMusicPath("progressBoxClick.mp3"),
    WEEK_TASK_BOX_CLICK = _getMusicPath("weekTaskBoxClick.mp3"),
    TREASURE_BOX_CLICK = _getMusicPath("treasureBoxClick.mp3"),
    TREASURE_BOX_OPEN = _getMusicPath("treasureBoxOpen.mp3"),
    TREASURE_BOX_REFRESH = _getMusicPath("treasureBoxRefresh.mp3"),
    PRIZE_TICKET_REVEAL = _getMusicPath("prizeTicketReveal.mp3"),
    PRIZE_FIREWORK = _getMusicPath("prizeFirework.mp3"),
    WEEKEND_CARNIVAL = _getMusicPath("weekendCarnival.mp3"),
}

function Res:getLoadingResList()
    return {
        Res.Texture.LOADING_ATLAS,
        Res.Spine.LOADING,
    }
end

function Res:getIconResList()
    return {
        Res.Spine.ICON_WEEKDAY,
        Res.Spine.ICON_WEEKEND,
    }
end

function Res:getV2IconResList()
    if EnvUtil:isMiniGame() then
        return {
            Res.Texture.ICON_WEEKDAY_MINIGAME,
            Res.Texture.ICON_WEEKEND_MINIGAME,
        }
    end
    return {
        Res.Spine.ICON_WEEKDAY_V2,
        Res.Spine.ICON_WEEKEND_V2,
    }
end

function Res:getMainResList()
    local appList = {
        Res.Spine.BOX_EFF_LVUP,
        Res.Spine.BOX,
        Res.Spine.FX_BOX,
        Res.Spine.QUAN,
        Res.Spine.QUAN_GLOW,
        Res.Spine.PRIZE_REWARD_VFX,
        Res.Spine.PRIZE_TICKET_CONVERT,
        Res.Spine.COLLECTION_GEM,
        Res.Texture.MAINBG,
        Res.Texture.MAINBG_WEEKEND,
        Res.Texture.WEEKEND_FRONT,
        Res.Spine.MOLE_MAGE,
        Res.Spine.NVWANGE,
        Res.Spine.WEEKEND_NVWANG,
        Res.Spine.CARD,
        Res.Music.PROGRESS_BOX_CLICK,
        Res.Music.WEEK_TASK_BOX_CLICK,
        Res.Music.TREASURE_BOX_CLICK,
        Res.Music.TREASURE_BOX_OPEN,
        Res.Music.TREASURE_BOX_REFRESH,
    }
    return {}, appList
end

return Res
