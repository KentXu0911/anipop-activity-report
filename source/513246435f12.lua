local StoreGiftModule = require "amf.feature.giftpackage.module.store.StoreGiftModule"
local StoreEventCenter = require "amf.feature.store.event.StoreEventCenter"
local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"
local ShopRewardEventCenter = require "amf.feature.localactivity.shopreward.event.ShopRewardEventCenter"
local Res = require "amf.feature.localactivity.shopreward.const.Res"

---@class ShopRewardGiftModule : StoreGiftModule
local ShopRewardGiftModule = class("ShopRewardGiftModule", StoreGiftModule)

local REPLACE_ACTIVITY_GIFT_DELAY = 0.8

local function disposeUnreplacedGiftView(giftView)
    if giftView and not giftView.isDisposed and giftView.dispose then
        giftView:dispose()
    end
end

function ShopRewardGiftModule:ctor(moduleName)
    StoreGiftModule.ctor(self, GiftPackageConst.ModuleType.SHOP_REWARD)
    self._moduleName = GiftPackageConst.ModuleType.SHOP_REWARD
    self._storeModuleKey = moduleName
end

function ShopRewardGiftModule:awake()
    if self._isAwoken then return end
    self._isAwoken = true

    StoreEventCenter:register(_G.StoreEvent.STORE_GIFT_WILL_REMOVE, self.onStoreGiftWillRemove, self)
    StoreEventCenter:register(_G.StoreEvent.STORE_AFTER_BUY, self.onStoreAfterBuy, self)
    GiftEventCenter:register(GiftEvent.STORE_PANEL_DC_FAKE_GIFT, self.onStorePanelDcFakeGift, self)
    GiftEventCenter:register(GiftEvent.STORE_PACKAGE_MODULE_RESOLVE, self.onStorePackageModuleResolve, self)
    ShopRewardEventCenter:register(ShopRewardEvent.ACT_MAIN_ENDED, self.onActMainEnded, self)
end

function ShopRewardGiftModule:getManager()
    return _G.amfBean("ShopRewardManager")
end

function ShopRewardGiftModule:needUpdate()
    return false
end

function ShopRewardGiftModule:isEnabled()
    return false
end

function ShopRewardGiftModule:getFakeGoodsId()
end

function ShopRewardGiftModule:onStorePackageModuleResolve(event)
    local data = event and event:getData() or {}
    if data.stageType ~= GiftPackageConst.StageType.STORE then return end
    if data.module then return end
    if not self:isActivityGiftData(data.packageData) then return end

    data.module = self
end

function ShopRewardGiftModule:doCreateGiftView(commonGiftData)
    if not commonGiftData then return nil end

    local ShopRewardStoreView = force_require "amf.feature.giftpackage.module.store.shopreward.view.ShopRewardStoreView"
    return ShopRewardStoreView:create(self, commonGiftData)
end

function ShopRewardGiftModule:onBuySuccess(storeGiftView)
    StoreGiftModule.onBuySuccess(self, storeGiftView)
end

function ShopRewardGiftModule:setSkin(giftView)
    if not giftView or giftView.isDisposed then return end
    if not giftView.layout then return end
    giftView.layout:setPreparedColorMode(_G.StoreConfig.ColorType.Yellow)
end

function ShopRewardGiftModule:onStoreAfterBuy(event)
    local data = event and event:getData() or {}
    local giftData = data.giftData
    self:onActivityGiftBought(giftData)
end

function ShopRewardGiftModule:onStoreGiftWillRemove(event)
    local data = event and event:getData() or {}
    if self:replaceRemovingActivityGiftWithOrigin(data) then
        data.handled = true
    end
end

function ShopRewardGiftModule:onStorePanelDcFakeGift(event)
    local manager = self:getManager()
    if not manager or not manager:isEnabled() then return end

    local data = event and event:getData() or {}
    if data.dcParam then
        data.dcParam.actid = tostring(manager:getConst().actId)
    end
end

function ShopRewardGiftModule:onActMainEnded()
    self:replaceAllActivityGiftsWithOrigin()
end


function ShopRewardGiftModule:isActivityPackageId(packageId)
    if not packageId then return false end

    local manager = self:getManager()
    if not manager then return false end

    local packageIdNum = tonumber(packageId)
    local replaces = manager:getModel():getDataByKey("replaces", {})
    for _, replaceInfo in ipairs(replaces) do
        if tonumber(replaceInfo.activityPackageId) == packageIdNum then
            return true
        end
    end

    return false
end

function ShopRewardGiftModule:isActivityGiftData(giftData)
    if not giftData or not giftData.getGoodsId then return false end
    if giftData.getModuleName and giftData:getModuleName() ~= GiftPackageConst.ModuleType.SHOP_REWARD then return false end
    return self:isActivityPackageId(giftData:getGoodsId())
end

function ShopRewardGiftModule:markActivityPackageBought(packageId)
    if not packageId then return end

    local manager = self:getManager()
    if not manager then return end

    local model = manager:getModel()
    local boughtPackageIdMap = model:getDataByKey("boughtPackageIdMap", {})
    local key = tostring(packageId)
    local boughtCount = boughtPackageIdMap[key] or boughtPackageIdMap[packageId] or 0
    if boughtCount > 0 then
        return false
    end

    boughtPackageIdMap[key] = boughtCount + 1
    model:setDataByKey("boughtPackageIdMap", boughtPackageIdMap)
    model:setDataByKey("periodTotalBuyCount", model:getDataByKey("periodTotalBuyCount", 0) + 1)
    return true
end

function ShopRewardGiftModule:getHiddenStoreGiftData(packageId)
    if not packageId then return end
    local manager = self:getManager()
    return manager and manager:getHiddenStoreGiftData(packageId)
end

function ShopRewardGiftModule:createBaseGiftView(giftData)
    if not giftData then return end

    local originHidden = giftData:getExtraValue("hidden")
    giftData:setExtraValue("hidden", false)
    local StoreGiftModuleBase = require "amf.feature.giftpackage.module.store.basegift.StoreGiftModule_Base"
    local module = StoreGiftModuleBase.new(GiftPackageConst.ModuleType.STORE_BASE)
    local giftView = module:doCreateGiftView(giftData)
    giftData:setExtraValue("hidden", originHidden)
    return giftView
end

function ShopRewardGiftModule:replaceActivityGiftWithOrigin(activityPackageId)
    local manager = self:getManager()
    local originPackageId = manager and manager:getOriginPackageIdByActivityPackageId(activityPackageId)
    local originGiftData = self:getHiddenStoreGiftData(originPackageId)
    if not originGiftData then return end

    local originGiftView = self:createBaseGiftView(originGiftData)
    local payload = {
        targetPackageId = activityPackageId,
        newGiftView = originGiftView,
    }
    StoreEventCenter:dispatch(_G.StoreEvent.STORE_REPLACE_GIFT_VIEW, payload)
    if payload.replaced then
        return originGiftView
    end

    disposeUnreplacedGiftView(originGiftView)
end

function ShopRewardGiftModule:replaceActivityGiftWithOriginDelay(activityPackageId)
    setTimeOut(function()
        self:replaceActivityGiftWithOrigin(activityPackageId)
    end, REPLACE_ACTIVITY_GIFT_DELAY)
end

function ShopRewardGiftModule:onStoreActivityEndedDelay(manager)
    setTimeOut(function()
        if not manager then return end
        manager:onStoreActivityEnded()
    end, REPLACE_ACTIVITY_GIFT_DELAY)
end

function ShopRewardGiftModule:replaceRemovingActivityGiftWithOrigin(data)
    local giftView = data and data.giftView
    local packageLayer = data and data.packageLayer
    if not giftView or not packageLayer or packageLayer.isDisposed then return false end
    if not giftView.getGiftData then return false end

    local giftData = giftView:getGiftData()
    if not self:isActivityGiftData(giftData) then return false end

    local manager = self:getManager()
    local originPackageId = manager and manager:getOriginPackageIdByActivityPackageId(giftData:getGoodsId())
    local originGiftData = self:getHiddenStoreGiftData(originPackageId)
    if not originGiftData then return false end

    local originGiftView = self:createBaseGiftView(originGiftData)
    local payload = {
        targetGiftView = giftView,
        newGiftView = originGiftView,
    }
    StoreEventCenter:dispatch(_G.StoreEvent.STORE_REPLACE_GIFT_VIEW, payload)
    if payload.replaced == true then
        return true
    end

    disposeUnreplacedGiftView(originGiftView)
    return false
end

function ShopRewardGiftModule:replaceAllActivityGiftsWithOrigin()
    local manager = self:getManager()
    if not manager then return end

    local replaces = manager:getModel():getDataByKey("replaces", {})
    for _, replaceInfo in ipairs(replaces) do
        self:replaceActivityGiftWithOrigin(replaceInfo.activityPackageId)
    end

    StoreEventCenter:dispatch(_G.StoreEvent.STORE_EXTENSIONS_REFRESH)
end

function ShopRewardGiftModule:onActivityGiftBought(giftData)
    if not self:isActivityGiftData(giftData) then return end

    local manager = self:getManager()
    if not manager then return end

    local buyHandledKey = tostring(manager:getPeriodId()) .. "_" .. tostring(giftData:getGoodsId())
    self.handledActivityGiftBuyMap = self.handledActivityGiftBuyMap or {}
    if self.handledActivityGiftBuyMap[buyHandledKey] then return end
    self.handledActivityGiftBuyMap[buyHandledKey] = true

    manager:dcJoin()
    self:markActivityPackageBought(giftData:getGoodsId())
    ShopRewardEventCenter:dispatch(ShopRewardEvent.BUY_COUNT_REFRESH, {
        packageId = giftData:getGoodsId(),
        remainBuyCount = manager:getRemainBuyCount(),
    })

    local activityEnded = manager:getRemainBuyCount() <= 0
    if activityEnded then
        self:onStoreActivityEndedDelay(manager)
        return
    end

    self:replaceActivityGiftWithOriginDelay(giftData:getGoodsId())
end

function ShopRewardGiftModule:getFeatureAndSource(type)
    if type == GiftPackageConst.DcChance.PAYMENT_TRACER then
        return "new_store", "reward_festival"
    end
end

function ShopRewardGiftModule:getResMap()
    return {
        labels = {
            "gift_layout_gold.label",
            "gift_layout_plugin.label",
        },
        files = Res:getStoreGiftResList()
    }
end

return ShopRewardGiftModule
