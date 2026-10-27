local Meta = {}

-- 限购礼包
Meta.LimitedGoods = {
    RMB1 = 3437,
    RMB3 = 3438,
    RMB6 = 3439,
    RMB12 = 3440,
    
    RMB30 = 3442,
    RMB68 = 3443,

    ResourceRMB1 = 3451,
    ResourceRMB3 = 3452,
    ResourceRMB6 = 3453,

    LiuChengRMB1 = 3529,
    LiuChengRMB3 = 3530,
    LiuChengRMB6 = 3531,
    LiuChengRMB12 = 3532,
    LiuChengRMB18 = 3533,
    LiuChengRMB30 = 3534,
    LiuChengRMB68 = 3535,
    LiuChengRMB98 = 3536,
    LiuChengRMB128 = 3537,
    LiuChengRMB168 = 3538,

    ChaoZhiRmb1 = 3539,
    ChaoZhiRmb12 = 3540,
    ChaoZhiRmb18 = 3541,

    TuJianRmb68 = 3542,

    JinDuRmb6 = 3543,
    JinDuRmb30 = 3544,
    JinDuRmb68 = 3545,
    JinDuRmb98 = 3546,

    PaiHangRMB238 = 3708,

    ZhiZumRMB238 = 3707,
}

-- 不限购礼包
Meta.UnlimitedGoods = {
    RMB6 = 3444,
    RMB12 = 3445,
    RMB18 = 3441,
    RMB30 = 3446,
    RMB68 = 3447,
    RMB98 = 3448,
    RMB128 = 3449,
    RMB168 = 3450,
}

Meta.GoodsName = {
    { goodsId = Meta.LimitedGoods.RMB1, showName = '超值特惠礼包'},
    { goodsId = Meta.LimitedGoods.RMB3, showName = '精选实惠礼包'},
    { goodsId = Meta.LimitedGoods.RMB6, showName = '畅销优惠礼包'},
    { goodsId = Meta.UnlimitedGoods.RMB6, showName = '畅销优惠礼包' },
    { goodsId = Meta.LimitedGoods.RMB12, showName = '超值助力礼包' },
    { goodsId = Meta.UnlimitedGoods.RMB12, showName = '超值助力礼包' },
    { goodsId = Meta.UnlimitedGoods.RMB18, showName = '丰厚道具礼包'},
    { goodsId = Meta.LimitedGoods.RMB30, showName = '精选优惠礼包'},
    { goodsId = Meta.UnlimitedGoods.RMB30, showName = '精选优惠礼包'},
    { goodsId = Meta.LimitedGoods.RMB68, showName = '极速畅享礼包'},
    { goodsId = Meta.UnlimitedGoods.RMB68, showName = '极速畅享礼包'},
    { goodsId = Meta.UnlimitedGoods.RMB98, showName = '豪华双倍礼包'},
    { goodsId = Meta.UnlimitedGoods.RMB128, showName = '金币多多礼包'},
    { goodsId = Meta.UnlimitedGoods.RMB168, showName = '畅快合合礼包'},

    { goodsId = Meta.LimitedGoods.ResourceRMB1, showName = '限时特惠礼包'},
    { goodsId = Meta.LimitedGoods.ResourceRMB3, showName = '惊喜划算礼包'},
    { goodsId = Meta.LimitedGoods.ResourceRMB6, showName = '超值畅享礼包'},

    { goodsId = Meta.LimitedGoods.LiuChengRMB1, showName = '超值购买'},
    { goodsId = Meta.LimitedGoods.LiuChengRMB3, showName = '超值购买'},
    { goodsId = Meta.LimitedGoods.LiuChengRMB6, showName = '超值购买'},
    { goodsId = Meta.LimitedGoods.LiuChengRMB12, showName = '超值购买'},
    { goodsId = Meta.LimitedGoods.LiuChengRMB18, showName = '超值购买'},
    { goodsId = Meta.LimitedGoods.LiuChengRMB30, showName = '超值购买'},
    { goodsId = Meta.LimitedGoods.LiuChengRMB68, showName = '超值购买'},
    { goodsId = Meta.LimitedGoods.LiuChengRMB98, showName = '超值购买'},
    { goodsId = Meta.LimitedGoods.LiuChengRMB128, showName = '超值购买'},
    { goodsId = Meta.LimitedGoods.LiuChengRMB168, showName = '超值购买'},

    { goodsId = Meta.LimitedGoods.ZhiZumRMB238, showName = '至尊优享礼包'},
}

--物资礼包
Meta.GiftRecommend = {
    [0] = { --默认payTag 0 没有giftList 不弹
    },
    [UsetPaymentTagServer.kNone] = {
        Meta.LimitedGoods.RMB1,
        Meta.LimitedGoods.RMB3,
        Meta.UnlimitedGoods.RMB6,
        Meta.UnlimitedGoods.RMB12,
        Meta.UnlimitedGoods.RMB18,
        Meta.UnlimitedGoods.RMB30,
        Meta.UnlimitedGoods.RMB68,
    },
    [UsetPaymentTagServer.kLow] = {
        Meta.LimitedGoods.RMB1,
        Meta.LimitedGoods.RMB3,
        Meta.UnlimitedGoods.RMB6,
        Meta.UnlimitedGoods.RMB12,
        Meta.UnlimitedGoods.RMB18,
        Meta.UnlimitedGoods.RMB30,
        Meta.UnlimitedGoods.RMB68,
    },
    [UsetPaymentTagServer.kMidLow] = {
        Meta.LimitedGoods.RMB1,
        Meta.LimitedGoods.RMB3,
        Meta.UnlimitedGoods.RMB6,
        Meta.UnlimitedGoods.RMB12,
        Meta.UnlimitedGoods.RMB18,
        Meta.UnlimitedGoods.RMB30,
        Meta.UnlimitedGoods.RMB68,
    },
    [UsetPaymentTagServer.kMidHigh] = {
        Meta.LimitedGoods.RMB3,
        Meta.LimitedGoods.RMB6,
        Meta.UnlimitedGoods.RMB12,
        Meta.UnlimitedGoods.RMB18,
        Meta.UnlimitedGoods.RMB30,
        Meta.UnlimitedGoods.RMB68,
        Meta.UnlimitedGoods.RMB98,
    },
    [UsetPaymentTagServer.kHigh_4] = {
        Meta.LimitedGoods.RMB6,
        Meta.LimitedGoods.RMB68,
        Meta.UnlimitedGoods.RMB18,
        Meta.UnlimitedGoods.RMB30,
        Meta.UnlimitedGoods.RMB98,
        Meta.UnlimitedGoods.RMB128,
    },
    [UsetPaymentTagServer.kHigh_5] = {
        Meta.LimitedGoods.RMB12,
        Meta.LimitedGoods.RMB68,
        Meta.UnlimitedGoods.RMB18,
        Meta.UnlimitedGoods.RMB30,
        Meta.UnlimitedGoods.RMB98,
        Meta.UnlimitedGoods.RMB128,
        Meta.UnlimitedGoods.RMB168,
    },
    [UsetPaymentTagServer.kHigh_6] = {
        Meta.LimitedGoods.RMB30,
        Meta.LimitedGoods.ZhiZumRMB238,
        Meta.UnlimitedGoods.RMB68,
        Meta.UnlimitedGoods.RMB98,
        Meta.UnlimitedGoods.RMB128,
        Meta.UnlimitedGoods.RMB168,
    },
}

--体力不足的推荐礼包
Meta.ResourceGiftRecommend = {
    [UsetPaymentTagServer.kNone] = { Meta.LimitedGoods.ResourceRMB1, Meta.LimitedGoods.ChaoZhiRmb1 },
    [UsetPaymentTagServer.kLow] = { Meta.LimitedGoods.ResourceRMB1, Meta.LimitedGoods.ChaoZhiRmb1 },
    [UsetPaymentTagServer.kMidLow] = { Meta.LimitedGoods.ResourceRMB3, Meta.LimitedGoods.ChaoZhiRmb12 },
    [UsetPaymentTagServer.kMidHigh] = { Meta.LimitedGoods.ResourceRMB3, Meta.LimitedGoods.ChaoZhiRmb12 },
    [UsetPaymentTagServer.kHigh_4] = { Meta.LimitedGoods.ResourceRMB6, Meta.LimitedGoods.ChaoZhiRmb18 },
    [UsetPaymentTagServer.kHigh_5] = { Meta.LimitedGoods.ResourceRMB6, Meta.LimitedGoods.ChaoZhiRmb18 },
    [UsetPaymentTagServer.kHigh_6] = { Meta.LimitedGoods.ResourceRMB6, Meta.LimitedGoods.ChaoZhiRmb18 },
}

Meta.ItemGoods = {
    LEVEL_2 = 3473,
    LEVEL_3 = 3474,
    LEVEL_4 = 3475,
    LEVEL_5 = 3476,
}

--流程礼包
Meta.GiftLiuCheng = {
    [0] = { --默认payTag 0 没有giftList 不弹
    },
    [UsetPaymentTagServer.kNone] = {
        Meta.LimitedGoods.LiuChengRMB1,
    },
    [UsetPaymentTagServer.kLow] = {
        Meta.LimitedGoods.LiuChengRMB1,
        Meta.LimitedGoods.LiuChengRMB3,
    },
    [UsetPaymentTagServer.kMidLow] = {
        Meta.LimitedGoods.LiuChengRMB3,
        Meta.LimitedGoods.LiuChengRMB1,
        Meta.LimitedGoods.LiuChengRMB6,
    },
    [UsetPaymentTagServer.kMidHigh] = {
        Meta.LimitedGoods.LiuChengRMB6,
        Meta.LimitedGoods.LiuChengRMB3,
        Meta.LimitedGoods.LiuChengRMB12,
    },
    [UsetPaymentTagServer.kHigh_4] = {
        Meta.LimitedGoods.LiuChengRMB30,
        Meta.LimitedGoods.LiuChengRMB18,
        Meta.LimitedGoods.LiuChengRMB68,
    },
    [UsetPaymentTagServer.kHigh_5] = {
        Meta.LimitedGoods.LiuChengRMB68,
        Meta.LimitedGoods.LiuChengRMB30,
        Meta.LimitedGoods.LiuChengRMB98,
    },
    [UsetPaymentTagServer.kHigh_6] = {
        Meta.LimitedGoods.LiuChengRMB128,
        Meta.LimitedGoods.LiuChengRMB98,
        Meta.LimitedGoods.LiuChengRMB168,
    },
}

Meta.judgeParam = {
    [UsetPaymentTagServer.kNone] = {
        cashNum = 19,
        buffTime = 5,
        failTime = 5,
        passTime = 6,
    },
    [UsetPaymentTagServer.kLow] = {
        energyNum = 5,
        cashNum = 29,
        passTime = 6,
    },
    [UsetPaymentTagServer.kMidLow] = {
        energyNum = 5,
        cashNum = 39,
        passTime = 5,
    },
    [UsetPaymentTagServer.kMidHigh] = {
        energyNum = 5,
        cashNum = 39,
        passTime = 5,
    },
    [UsetPaymentTagServer.kHigh_4] = {
        energyNum = 5,
        cashNum = 59,
        passTime = 4,
    },
    [UsetPaymentTagServer.kHigh_5] = {
        energyNum = 5,
        cashNum = 59,
        passTime = 4,
    },
    [UsetPaymentTagServer.kHigh_6] = {
        energyNum = 5,
        cashNum = 100,
        passTime = 3,
    },
}

--进度过半礼包
Meta.JinduHalfLibao = {
    [0] = { --默认payTag 0 没有giftList 不弹
    },
    [UsetPaymentTagServer.kNone] = {
        Meta.LimitedGoods.JinDuRmb6,
    },
    [UsetPaymentTagServer.kLow] = {
        Meta.LimitedGoods.JinDuRmb6,
    },
    [UsetPaymentTagServer.kMidLow] = {
        Meta.LimitedGoods.JinDuRmb30,
    },
    [UsetPaymentTagServer.kMidHigh] = {
        Meta.LimitedGoods.JinDuRmb30,
    },
    [UsetPaymentTagServer.kHigh_4] = {
        Meta.LimitedGoods.JinDuRmb68,
    },
    [UsetPaymentTagServer.kHigh_5] = {
        Meta.LimitedGoods.JinDuRmb68,
    },
    [UsetPaymentTagServer.kHigh_6] = {
        Meta.LimitedGoods.JinDuRmb98,
    },
}

Meta.JinDuFullGoodsId = Meta.LimitedGoods.PaiHangRMB238 --进度满礼包
Meta.TuJianLibaoGoodsId = Meta.LimitedGoods.TuJianRmb68 --图鉴礼包

--超值标签
Meta.ChaoZhiTipShowGoodsIds = {
    Meta.LimitedGoods.RMB68,
    Meta.LimitedGoods.ZhiZumRMB238,
}

function Meta:getName(goodsId)
    for k, v in pairs(self.GoodsName) do
        if v.goodsId == goodsId then
            return v.showName
        end
    end
end

function Meta:getJinduHalfGift(payTag)
    return table.clone(self.JinduHalfLibao[payTag])
end

function Meta:getRecommendGift(payTag)
    return table.clone(self.GiftRecommend[payTag])
end

function Meta:checkIsLimit(goodsId)
    return table.exist(self.LimitedGoods, goodsId)
end

function Meta:getPrice(goodsId)
    for k, v in pairs(self.LimitedGoods) do
        if v == goodsId then
            local number = string.match(k, "(%d+)$")
            return tonumber(number)
        end
    end

    for k, v in pairs(self.UnlimitedGoods) do
        if v == goodsId then
            local number = string.match(k, "(%d+)$")
            return tonumber(number)
        end
    end
end

return Meta