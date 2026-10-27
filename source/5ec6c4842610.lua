_G.PromoteLowConst = {}

PromoteLowConst.SIGN_DAY_COUNT = 7
if EnvUtil:isMiniGame() then
PromoteLowConst.ACT_ID = 5067 -- 小游戏用5067
else
PromoteLowConst.ACT_ID = 5061
end

PromoteLowConst.DC_FEATURE     = "low_active"                  -- feature
PromoteLowConst.DC_SOURCE      = "main_panel_reward"           -- source
if EnvUtil:isMiniGame() then
PromoteLowConst.StarBuff_ID    = 55042  
else
PromoteLowConst.StarBuff_ID    = 55039
end
-- 文案
PromoteLowConst.Desc = {
    -- 按钮部分文案
    FULL_DES            = "<color=#f36700>新关发布后</c><color=#c9835d>，获取更多贴纸</color>",
    TODAY_SIGN_DES      = "<color=#f36700>明日再来</c><color=#c9835d>，获取更多贴纸</color>",
    CANREWARD_DES       = "<color=#f36700>贴纸已集满</c><color=#c9835d>，点击宝箱领取奖励~</color>",
    DESC_SIGN_FULL      = "<color=#f36700>贴纸集齐</c><color=#c9835d>，大奖已领取</color>",

    -- npctip文案
    TODAY_SIGN_TIP      = "明日再来，获取更多贴纸",
    TODAY_SIGN_ANIOVER_TIP      = "今日贴纸已收集，明日可获取更多贴纸~",
    -- 点击空贴纸tip
    TODAY_NOT_SIGN_DES  = "今日闯关，获取更多贴纸",

    -- topDes 文案
    -- TOP_DES_FMJ         = "每日闯过新关收集贴纸，集满赢取超强道具！",
    -- TOP_DES_MJFMX       = "每日补星收集贴纸，集满赢取超强道具！",
    -- TOP_DES_MJMX        = "每日闯过新关收集贴纸，集满赢取超强道具！",

    TIP_BOX_REWARDED    = "贴纸集齐，大奖已领取",
    TIP_ACT_END         = "每日一贴活动已结束！",
    TIP_COLLECT         = "再收集%s枚贴纸，就能获得奖励了~",
}

if EnvUtil:isApp() then
    PromoteLowConst.Desc.FULL_DES            = "<color=#C9835E>新关发布后，获取更多贴纸</color>"
    PromoteLowConst.Desc.TODAY_SIGN_DES      = "<color=#C9835E>明日再来，获取更多贴纸</color>"
    PromoteLowConst.Desc.CANREWARD_DES       = "<color=#C9835E>贴纸已集满，点击宝箱领取奖励~</color>"
    PromoteLowConst.Desc.DESC_SIGN_FULL      = "<color=#C9835E>贴纸集齐，大奖已领取</color>"
    PromoteLowConst.Desc.TOP_DES_FMJ         = "每日闯过新关收集贴纸，集满赢取超强道具！"
    PromoteLowConst.Desc.TOP_DES_MJFMX       = "每日补星收集贴纸，集满赢取超强道具！"
    PromoteLowConst.Desc.TOP_DES_MJMX        = "每日闯过新关收集贴纸，集满赢取超强道具！"
    PromoteLowConst.Desc.TIP_ACT_END         = "贴纸赢好礼活动已结束！"
end


PromoteLowConst.Error = {
    ["737139"] = "活动已结束，请关闭活动页面重试",
    ["737140"] = "贴纸数据异常，请关闭活动页面重试",
    ["737141"] = "奖励已领取过，无法重复领取",
}