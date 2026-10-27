local ActivityGiftPackageModule =
    require "amf.feature.giftpackage.module.activity.ActivityGiftPackageModule"
local deferred = require "amf.script.sugar.deferred"

local GiftModule =
    class("LayeredTileMatchGiftModule", ActivityGiftPackageModule)

local DAILY_GIFT_TOKEN_COST_THRESHOLD = 20
local DAILY_GIFT_GROUP = "SPECIAL_OFFER"

local DAILY_GIFT_RECOMMENDATIONS = {
    [0] = { limited = { 1, 3 }, unlimited = 6 },
    [1] = { limited = { 1, 3 }, unlimited = 6 },
    [2] = { limited = { 1, 3 }, unlimited = 6 },
    [3] = { limited = { 3, 6 }, unlimited = 12 },
    [4] = { limited = { 6, 18, 30 }, unlimited = 68 },
    [5] = { limited = { 30, 12, 68, 98 }, unlimited = 128 },
    [6] = { limited = { 68, 30, 98, 128 }, unlimited = 168 },
}

local function getPriceKey(price)
    price = tonumber(price)
    if not price then return end
    return math.floor(price * 100 + 0.5)
end

local function isDailyGiftPackage(package)
    if not package or not package.getExtraValue then return false end
    return package:getExtraValue("group") == DAILY_GIFT_GROUP
end

local function isPackageAvailable(package)
    if not package then return false end
    if package.isLimited and package:isLimited() then
        return false
    end
    local goodsId = package.getGoodsId and package:getGoodsId()
    local goods = goodsId and GoodsManager:getGoods(goodsId)
    return goods ~= nil
end

local function getPackagePriceKey(package)
    if not package or not package.getGoodsId then return end
    local goods = GoodsManager:getGoods(package:getGoodsId())
    return goods and getPriceKey(goods:getPrice())
end

local function isLimitedPackage(package)
    return (tonumber(package:getCanBuyCount()) or 0) > 0
end

function GiftModule:ctor(mgr)
    self._moduleName = mgr:getConst().moduleName
    self._actId = mgr:getConst().actId
    self._version = 0
    self.mgr = mgr
end

function GiftModule:pullGift()
    self._packages = nil
    local promise = deferred.new()

    self:pullOnce(10, true):next(function()
        promise:resolve(self._packages or {})
    end, function(errorCode)
        promise:reject(errorCode)
    end)
    return promise
end

function GiftModule:getPackageIdsByGroup(group)
    local packages = {}
    for _, package in ipairs(self._packages or {}) do
        local limited =
            package.isLimited and package:isLimited()
        if package:getExtraValue("group") == group
            and not limited then
            table.insert(packages, package)
        end
    end
    table.sort(packages, function(left, right)
        local leftPriority = tonumber(
            left:getExtraValue("displayPriority")
        ) or math.huge
        local rightPriority = tonumber(
            right:getExtraValue("displayPriority")
        ) or math.huge
        if leftPriority ~= rightPriority then
            return leftPriority < rightPriority
        end
        local leftGoodsId =
            tonumber(left:getGoodsId()) or math.huge
        local rightGoodsId =
            tonumber(right:getGoodsId()) or math.huge
        return leftGoodsId < rightGoodsId
    end)
    local packageIds = {}
    for _, package in ipairs(packages) do
        table.insert(packageIds, package:getGoodsId())
    end
    return packageIds
end

function GiftModule:getPackageById(goodsId)
    for _, package in ipairs(self._packages or {}) do
        if tonumber(package:getGoodsId()) == tonumber(goodsId) then
            return package
        end
    end
end

function GiftModule:getPackageExtra(goodsId)
    local package = self:getPackageById(goodsId)
    return package and package.extra or {}
end

function GiftModule:getPackageBuyLimit(goodsId)
    local package = self:getPackageById(goodsId)
    if not package then
        return
    end
    return math.max(
        0,
        math.floor(tonumber(package:getCanBuyCount()) or 0)
    )
end

function GiftModule:getPackageRemainBuyTimes(goodsId)
    local package = self:getPackageById(goodsId)
    if not package then
        return
    end
    local totalCanBuyTimes =
        tonumber(package:getCanBuyCount()) or 0
    if totalCanBuyTimes <= 0 then return end
    return math.max(
        0,
        totalCanBuyTimes
            - (tonumber(package:getAlreadyBuyCount()) or 0)
    )
end

function GiftModule:getPackageGroupRemainBuyTimes(group)
    local totalCanBuyTimes = 0
    local alreadyBuyTimes = 0
    for _, package in ipairs(self._packages or {}) do
        if package:getExtraValue("group") == group then
            local packageTotal =
                tonumber(package:getCanBuyCount()) or 0
            if packageTotal > 0 then
                totalCanBuyTimes =
                    totalCanBuyTimes + packageTotal
                alreadyBuyTimes = alreadyBuyTimes
                    + math.max(
                        0,
                        tonumber(package:getAlreadyBuyCount()) or 0
                    )
            end
        end
    end
    return math.max(0, totalCanBuyTimes - alreadyBuyTimes)
end

function GiftModule:getDailyGiftPaymentTag()
    if not UserTagManager or not UserTagManager.getUserPaymentTag2 then
        return 0
    end
    local rawTag = UserTagManager:getUserPaymentTag2()
    local tagMap = UserPaymentTag2Index or {}
    return tagMap[rawTag] or 0
end

function GiftModule:selectDailyGiftPackage(packages, payTag)
    local recommendation =
        DAILY_GIFT_RECOMMENDATIONS[tonumber(payTag) or 0]
            or DAILY_GIFT_RECOMMENDATIONS[0]

    local function findPackage(price, limited)
        local targetPriceKey = getPriceKey(price)
        for _, package in ipairs(packages or {}) do
            if isDailyGiftPackage(package)
                and isPackageAvailable(package)
                and isLimitedPackage(package) == limited
                and getPackagePriceKey(package) == targetPriceKey then
                return package
            end
        end
    end

    for _, price in ipairs(recommendation.limited) do
        local package = findPackage(price, true)
        if package then return package end
    end
    return findPackage(recommendation.unlimited, false)
end

function GiftModule:checkCanPopDailyGiftStage4()
    if not self.mgr then
        return false
    end
    local periodCostChallengeTokenNum =
        tonumber(self.mgr:getBattlePassValue()) or 0
    if periodCostChallengeTokenNum <= DAILY_GIFT_TOKEN_COST_THRESHOLD then
        return false
    end
    return true
end

function GiftModule:showDailyGiftPanel(package, onPopOver)
    local goodsId = package and package.getGoodsId
        and package:getGoodsId()
    if not goodsId or not GoodsManager:getGoods(goodsId) then
        safeRunCall(onPopOver)
        return
    end
    local finished = false
    local function finish()
        if finished then return end
        finished = true
        safeRunCall(onPopOver)
    end

    local ProcessGiftPanelVM = require(
        "amf.feature.localactivity.layeredtilematch.view.ProcessGiftPanelVM"
    )
    local vm = ProcessGiftPanelVM.Builder.new()
        :setGoodsId(goodsId)
        :setBuyHandler(function(
            successCallback,
            failCallback,
            cancelCallback
        )
            self.mgr:requestBuyDailyGiftPackage(
                goodsId,
                successCallback,
                failCallback,
                cancelCallback
            )
        end)
        :setCloseCallback(finish)
        :setLoadResFailCallback(function()
            finish()
        end)
        :build()

    if not vm then
        finish()
        return
    end
    self.mgr:managePanelVM(vm)
    vm:popout()
end

function GiftModule:popDailyGiftStage4(onPopOver)
    if not self:checkCanPopDailyGiftStage4() then
        safeRunCall(onPopOver)
        return
    end

    local pullPromise = self.mgr:pullTicketRefillGoods()
    if not pullPromise then
        safeRunCall(onPopOver)
        return
    end
    pullPromise:next(function(packages)
        if not self.mgr then
            safeRunCall(onPopOver)
            return
        end
        if not self.mgr:isEnabled() then
            safeRunCall(onPopOver)
            return
        end
        if not self.mgr:isInMainTime() then
            safeRunCall(onPopOver)
            return
        end

        local payTag = self:getDailyGiftPaymentTag()
        local package = self:selectDailyGiftPackage(
            packages,
            payTag
        )
        if not package then
            safeRunCall(onPopOver)
            return
        end
        self:showDailyGiftPanel(package, onPopOver)
    end, function(errorCode)
        safeRunCall(onPopOver)
    end)
end

return GiftModule
