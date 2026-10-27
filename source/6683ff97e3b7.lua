local Res = {}
local RES_ROOT = "amf/activity/promotelow/"

Res.Frame = {
    JI_SHADOW = "DiHuo/MainPanel/shandow",
    JI = "DiHuo/MainPanel/ji",
}

Res.File = {
    BG = RES_ROOT .. "texture/bg1.png",
    OPEN_BOX = RES_ROOT .. "texture/openBox.png",
}

Res.Spine = {
    FINISH = RES_ROOT .. "spine/finish_fx.skel",
    TIEZHI = RES_ROOT .. "spine/tiezhi.skel",
    CARD_EFF = RES_ROOT .. "spine/reward_vfx.skel",
    ACTIVE = RES_ROOT .. "spine/finish_fx.skel",
}

Res.JiPosConfig = {
    ccp(64.5, 215),
    ccp(205, 215),
    ccp(348, 215),
    ccp(488, 215),
    ccp(128, 64),
    ccp(276, 64),
    ccp(422, 64),
}

return Res