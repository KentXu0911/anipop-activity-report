local OpenCardAnimConfig = {}

-- 时间常量
OpenCardAnimConfig.FRAME_TIME = 1/30

-- 动画状态枚举
OpenCardAnimConfig.AnimState = {
    SHOW = 1,       -- 展示卡包，等待玩家点击开包
    OPEN = 2,       -- 开始准备开包
    OPENING = 3,    -- 逐个开包动画
    STOPATLAST = 4, -- 开包动画进行到最后一步停在那不动，直到玩家点击继续才结束动画
    SKIP = 5,       -- 点击跳过（大跳）直接展示最终结果
    FINISH = 6,     -- 动画结束
}

-- 展示卡包时两包的间隔 1~8个包时间隔不一样
OpenCardAnimConfig.CardPackSpace = {
    0,
    10,
    20,
    34,
    35,
    37,
    37,
    40
}

-- 卡片位置配置
OpenCardAnimConfig.CardPos = {
    {
        ccp(0, 0),
    },
    {
        ccp(-108, 0),
        ccp(108, 0),
    },
    {
        ccp(0, 138),
        ccp(-108, -138),
        ccp(108, -138),
    },
    {
        ccp(-108, 138),
        ccp(108, 138),
        ccp(-108, -138),
        ccp(108, -138),
    },
    {
        ccp(-108, 138),
        ccp(108, 138),
        ccp(-216, -138),
        ccp(0, -138),
        ccp(216, -138),
    },
    {
        ccp(-216, 138),
        ccp(0, 138),
        ccp(216, 138),
        ccp(-216, -138),
        ccp(0, -138),
        ccp(216, -138),
    }
}

OpenCardAnimConfig.CardScale = {
    FewCardMaxCount = 4,
    FewCard = 0.6,
    Default = 0.5,
}

-- 资源路径配置
OpenCardAnimConfig.ResPath = {
    CardPackSpine = "amf/activity/collectcard/spine/opencardflow/kaimangdai.skel",
    StarSpine = "amf/activity/collectcard/spine/opencardflow/shouqu_xing.skel",
    NewCardSpine = "amf/activity/collectcard/spine/opencardflow/xinka.skel",
    IconFeedbackSpine = "amf/activity/collectcard/spine/opencardflow/icon_fankui.skel",
    SkipLightSpine = "amf/activity/collectcard/spine/opencardflow/zhegaiguang.skel",
    FlowSkipBtn = "amf/activity/collectcard/materials/flowskipBtn.png",
    StarShopBg = "amf/activity/collectcard/materials/starShopBg.png",
    StarShopIcon = "amf/activity/collectcard/materials/starShopIcon.png",
}

-- 皮肤列表配置
OpenCardAnimConfig.SkinList = {
    "lv", "lan", "zi", "huang", "cai"
}

-- 动画时长配置（单位：帧）
OpenCardAnimConfig.AnimDuration = {
    CardPackScale = 6,
    CardPackMove = 7,
    CardPackFinalScale = 5,
    CardAppearMove = 6,
    CardAppearScaleUp = 3,
    CardAppearScaleDown = 3,
    StarFlyDelay = 23,
    StarFlyDuration = 20,
    ButtonFadeIn = 2,
    ButtonFadeOut = 2,
    CardDelay = 12,
    ScaleUp = 3,
    ScaleDown = 3,
    MoveUp = 4,
    MoveDown = 6,
    RandomMin = 1,
    RandomMax = 10,
    HideDelay = 8,
    ShowDelay = 5,
    ButtonShow = 5,
}

return OpenCardAnimConfig
