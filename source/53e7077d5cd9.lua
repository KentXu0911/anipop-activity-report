local ROOT = "amf/activity/shopreward/"
local function _getSpinePath(name)
    return ROOT.."spine/"..name
end

local function _getTexturePath(name)
    return ROOT.."texture/"..name
end

local Res = {}

Res.Spine = {
    MAIN = _getSpinePath("huikuikuanghuan.skel"),
    TX = _getSpinePath("tx.skel"),
    SAOGUANG = _getSpinePath("saoguang.skel"),
    GOLDTAG = _getSpinePath("ui1_1_fx.skel"),
    ICON = _getSpinePath("icon.skel"),
    ICON_V2 = _getSpinePath("icon_huikuikuanghuan.skel"),
    HEADER_ANI = _getSpinePath("ui2_1_fx.skel"),
    HEADER_SAO = _getSpinePath("shop_light_fx.skel"),
    ADD_ANI = _getSpinePath("ui3_fx.skel"),
    ZHAN = _getSpinePath("ui2_3_fx.skel"),
}

Res.Texture = {
    ICON_MINIGAME = _getSpinePath("icon_huikuikuanghuan_minigame.png"),
    ICON_V2_BG = _getSpinePath("icon_v2_bg.png"),
}

Res.Plist = {
    NUMFRAME = _getTexturePath("ShopRewardFrames.plist"),
    SHOPHEADER = _getTexturePath("ShopRewardHeaderNode.plist"),
    ADDSTEPNODE = _getTexturePath("ShopRewardAddStepNode.plist"),
}

Res.DigitFramePrefix = "ShopRewardFrames/ShopRewardFrames/"

function Res:getMainResList()
    return {}, {
        Res.Spine.MAIN,
        Res.Plist.NUMFRAME,
        Res.Spine.TX,
        Res.Spine.SAOGUANG
    }
end

function Res:getStoreGiftResList()
    return {
        Res.Spine.ZHAN,
        Res.Plist.NUMFRAME
    }
end

function Res:getStoreHeaderResList()
    return {
        Res.Plist.SHOPHEADER,
        Res.Spine.HEADER_ANI,
        Res.Spine.HEADER_SAO
    }
end

function Res:getGoldTagResList()
    return {
        Res.Spine.GOLDTAG,
    }
end

function Res:getAddStepResList()
    return {
        Res.Plist.ADDSTEPNODE,
        Res.Plist.NUMFRAME,
        Res.Spine.ADD_ANI
    }
end


return Res
