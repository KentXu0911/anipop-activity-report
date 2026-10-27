local ShopRewardConst = {}

ShopRewardConst.actId = 8076
ShopRewardConst.actChName = "回馈狂欢商店促销券"
ShopRewardConst.gameName = "shop_reward"

ShopRewardConst.DcPayment = {
    FEATURE = "new_store",
    SOURCE = "reward_festival",
}

ShopRewardConst.LocalPushType = LocalPushConst and LocalPushConst.LocalPushType.SHOP_REWARD or 70
ShopRewardConst.LocalPushGroupKey = "shop_reward"
ShopRewardConst.LocalPushHours = {10, 20}
ShopRewardConst.LocalPushCutoffSeconds = 4 * 60 * 60

ShopRewardConst.ActivityEndBroadCastText = "回馈狂欢活动已结束，记得查看商店里的更多优惠哦~"

ShopRewardConst.infoPrefix = "userInfo"
ShopRewardConst.configPrefix = "localConfig"
ShopRewardConst.timePrefix = "activityTime"

return ShopRewardConst
