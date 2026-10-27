local Meta = {}

Meta.ModuleName = "waterfallProgress2025"

Meta.IconTipText = {
    "厂家促销敢买敢送！",
    "买的多送的多！"
}

Meta.AUTOPOPTYPE = {
    ENERGY = 1,
    CONTINUEFAIL = 2,
    LOGIN = 3,
    WINDCOIN = 4,
}

----------------------------强弹时机检测----------------------------
--风车币余量
function Meta.checkRemainWindCoin(checkCount)
    checkCount = checkCount or 30
    local coinNumber = _G.amfBean("UserManager"):getCash()
	printx(33, "Meta.checkRemainWindCoin", coinNumber, checkCount, coinNumber < checkCount)
    return coinNumber < checkCount and Meta.AUTOPOPTYPE.WINDCOIN or false
end
--精力余量
function Meta.checkRemainEnergy(checkCount)
    checkCount = checkCount or 5
    local energyState = _G.amfBean("UserEnergyManager"):getEnergyState()
    if energyState == UserEnergyState.INFINITE then
		printx(33, "Meta.checkRemainEnergy", "UserEnergyState.INFINITE", false)
        return false
    end
    local curEnergy = _G.amfBean("UserEnergyManager"):getEnergy()
	printx(33, "Meta.checkRemainEnergy", curEnergy, checkCount, curEnergy < checkCount)
    return curEnergy < checkCount and Meta.AUTOPOPTYPE.ENERGY or false
end
--连续失败次数
function Meta.checkContinueFailCount(checkCount)
    checkCount = checkCount or 3
    local failCount = _G.amfBean("WaterfallGiftProgressManager"):getContinueFailCount() or 0
	printx(33, "Meta.checkContinueFailCount", failCount, checkCount, failCount >= checkCount)
    return failCount >= checkCount and Meta.AUTOPOPTYPE.CONTINUEFAIL or false
end
--场景234强弹
function Meta.checkOnEnterAutoPop()
	printx(33, "Meta.checkOnEnterAutoPop")
	return Meta.AUTOPOPTYPE.LOGIN
end

-- 强弹时机与场景检测 与数值表中对应
Meta.AutoPopDefinition = {
	Meta.checkRemainWindCoin,
	Meta.checkRemainEnergy,
	Meta.checkOnEnterAutoPop,
	Meta.checkContinueFailCount,
}

Meta.DyOfferGuideId = {
    PAY_END_1 = 101,
    PAY_END_2 = 102,
    PAY_END_3 = 103,
    PAY_END_4 = 104,
    PRICE_ANI_1 = 201,
    PRICE_ANI_3 = 203,
    PRICE_ANI_6 = 206,
    PRICE_ANI_12 = 212,
    PRICE_ANI_30 = 230,
    PRICE_ANI_68 = 268,
    PRICE_ANI_128 = 128,
    PRICE_ANI_168 = 168,
    PRICE_ANI_328 = 328,
}

return Meta

