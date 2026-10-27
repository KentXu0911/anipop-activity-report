require "amf.feature.giftpackage.config.GiftPackageConst"

local ReturnGiftConst = {}

ReturnGiftConst.ModuleName = "returnGift"
ReturnGiftConst.ActId = 3082

ReturnGiftConst.State = {
    NONE = 0,
    PACKAGE_1_BUYING = 1,
    PACKAGE_1_BOUGHT_CD = 2,
    PACKAGE_2_BUYING = 3,
    PACKAGE_2_REWARDING = 4,
    PACKAGE_2_DONE_CD = 5,
    PACKAGE_3_BUYING = 6,
    FINISHED = 7,
}

ReturnGiftConst.Status = {
    UNAVAILABLE = 0,
    CAN_PULL = 1,
    REWARDING = 2,
    NOT_MATCH = 3,
}

ReturnGiftConst.PackageType = {
    NONE = 0,
    PACKAGE_1 = 1,
    PACKAGE_2 = 2,
    PACKAGE_3 = 3,
}

ReturnGiftConst.Scene = {
    VINE = GiftPackageConst.StageType.VINE_SCENE,
    STORE = GiftPackageConst.StageType.STORE,
    START = GiftPackageConst.StageType.START_PANEL,
    ADD_STEP = GiftPackageConst.StageType.ADD_STEP,
}

ReturnGiftConst.PackageName = {
    [ReturnGiftConst.PackageType.PACKAGE_1] = "回归启程包",
    [ReturnGiftConst.PackageType.PACKAGE_2] = "自由畅玩包",
    [ReturnGiftConst.PackageType.PACKAGE_3] = "豪华爽玩包",
}

ReturnGiftConst.Tip = {
    EXPIRED = "%s特惠活动已结束！",
    REWARD_EXPIRED = "领奖时间已结束",
    NETWORK_BAD = "当前网络情况不佳，请稍后再试",
}

ReturnGiftConst.FlyItemDealy = 0
ReturnGiftConst.FlyItemShandowNum = 3
--小游戏飞动画延迟
if EnvUtil:isMiniGame() then
    ReturnGiftConst.FlyItemDealy = 0.1
    ReturnGiftConst.FlyItemShandowNum = 2
end
-- ReturnGiftConst.FlyItemDealy = 0.1 --debug


return ReturnGiftConst
