local Const = {}
Const.PACKAGE_MODULE_VERSION = 1     -- 礼包版本
Const.actOpenVersion = 1
Const.actId = 3077
Const.actChName = "春田合合"
Const.actSource = "mergeevolution/Config.lua"

Const.gameName = "small_merge"            -- 打点用
Const.dcFeature = "small_merge"            -- 打点用

Const.downloadLabels = {
    "mergeevolution_pub",
    "mergeevolution_autopop",
}

Const.needLoadFiles = {
    "amf/activity/mergeevolution/common/material/collection.png",
}

Const.infoPrefix = "userInfo"
Const.configPrefix = "localConfig"
Const.timePrefix = "timeInfo"

Const.MapStatus = {
    LOCK = 1,           -- 进行中，包括未解锁和解锁未领奖
    FINISHED = 2,       -- 已领地图奖励
    MOSAIC = 3,         -- 已镶嵌宝石
}

Const.haptics = {

}

Const.ActProps = {
    COLLECTION = 52938,
    SCORE_BUFF_20 = 52939,
    SCORE_BUFF_50 = 52940,
    
}

Const.RealRewards = {
    REAL_REWARD_1 = 80292,
    REAL_REWARD_2 = 80299,
}

Const.SkinMap = {
    SPRING_2026_03 = 1,
    SPRING_2026_05 = 2,
    SPRING_2026_06 = 3,
    SPRING_2026_07 = 4,
}

Const.ResInPack = {
     -- texture
    COLLECTION = "/material/collection.png",      --体力icon
    MATERIAL =  "/material/material.plist",      --棋子图标
    --spine
    BOX_GEM = "/spine/baoxiang_zuanshi.skel",    --宝石动画
    
}

Const.PanelUIInPack = {
    YINLIU_PANEL = ".YinliuPanel_UI",
    PROCESS_GIFT_PANEL = ".ProcessGiftPanel_UI",
}

Const.IsResOrUICommon = {
    [Const.ResInPack.COLLECTION] = true,
    [Const.PanelUIInPack.PROCESS_GIFT_PANEL] = true,
}

Const.SkinPath = {
    [Const.SkinMap.SPRING_2026_03] = "spring_2026_05",
    [Const.SkinMap.SPRING_2026_05] = "spring_2026_05",
    [Const.SkinMap.SPRING_2026_06] = "spring_2026_06",
    [Const.SkinMap.SPRING_2026_07] = "spring_2026_07",
}

Const.OnceGuideIndexTable = {
    2,   -- 新手引导2-5
    3,
    4,
    5,
}

function Const:getResPath(Res)
    local mgr = _G.amfBean("MergeEvolutionManager")
    local skin = mgr:getModel():getSkin()
    local id = self:getSkinId(skin)
    if Const.IsResOrUICommon[Res] then
        return "amf/activity/mergeevolution/common" .. Res
    else
        return "amf/activity/mergeevolution/skin/" .. Const.SkinPath[id] .. Res
    end
end

function Const:getUIPath(UI)
    local mgr = _G.amfBean("MergeEvolutionManager")
    local skin = mgr:getModel():getSkin()
    local id = self:getSkinId(skin)
    if Const.IsResOrUICommon[UI] then
        return "amf.feature.localactivity.mergeevolution.view.uisource" .. UI
    else
        return "amf.feature.localactivity.mergeevolution.view.uisource.".. Const.SkinPath[id] .. UI
    end
end

function Const:getSkinId(key)
    return self.SkinMap[string.upper(key)] or 1
end

Const.TipText = {
    [1] = "活动开启，来参与吧！",
    [2] = "有奖励可以领取！",
    [3] = "体力充足，来合成吧！",
}

Const.DRAINAGE_ENERGY = 50
Const.DRAINAGE_POP_MAX = 2

return Const
